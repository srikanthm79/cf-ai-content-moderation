/**
 * AIModerationManager.cfc
 * 
 * A simple and straight-forward library to setup and manage AI-powered content moderation
 * in Adobe ColdFusion and Lucee, integrating with Google Perspective API and Microsoft Azure Content Moderator.
 * 
 * @author Srikanth Madishetti
 * @version 1.0.0
 */
component {
    /**
     * Initialize the AI Moderation Manager with configuration
     * 
     * @param struct config Optional configuration overrides
     * @return com.madishetti.aiModeration.AIModerationManager
     */
    public function init(struct config = {}) {
        // Load default configuration
        var configPath = expandPath("/config/aiConfig.json");
        
        if (!fileExists(configPath)) {
            throw(type="com.madishetti.aiModeration.ConfigError", message="Configuration file not found at #configPath#");
        }
        
        var defaultConfig = deserializeJSON(fileRead(configPath));
        
        // Merge with provided config
        for (var key in config) {
            defaultConfig[key] = config[key];
        }
        
        // Store configuration
        variables.config = defaultConfig;
        
        // Initialize services with config
        variables.googleService = createObject("component", "com.madishetti.aiModeration.services.GoogleService").init(variables.config);
        variables.azureService = createObject("component", "com.madishetti.aiModeration.services.AzureService").init(variables.config);
        
        return this;
    }
    
    /**
     * Moderate content using enabled AI services
     * 
     * @param string content The content to analyze (text or base64 image)
     * @param string contentType The type of content ("text" or "image")
     * @return struct Standardized results from all enabled moderation services
     */
    public any function moderateContent(required string content, required string contentType) {
        var results = {
            "success": true,
            "isAppropriate": true,
            "confidence": 0,
            "flags": []
        };
        
        try {
            // Validate content type
            if (contentType != "text" && contentType != "image") {
                throw(type="com.madishetti.aiModeration.InvalidContentType", 
                      message="Content type must be either 'text' or 'image'");
            }
            
            var serviceCount = 0;
            
            // For text content
            if (contentType == "text") {
                if (variables.config.enableGooglePerspective) {
                    try {
                        var googleResult = variables.googleService.analyzeText(
                            content,
                            variables.config.options.language ?: "en"
                        );
                        updateResults(results, googleResult);
                        serviceCount++;
                    } catch (any e) {
                        rethrow;
                    }
                }
                
                if (variables.config.enableAzureModerator) {
                    try {
                        var azureResult = variables.azureService.analyzeText(
                            content,
                            variables.config.azureEndpoint,
                            variables.config.azureAPIKey
                        );
                        updateResults(results, azureResult);
                        serviceCount++;
                    } catch (any e) {
                        rethrow;
                    }
                }
            }
            
            // For image content
            if (contentType == "image") {
                if (variables.config.enableAzureModerator) {
                    try {
                        var azureResult = variables.azureService.analyzeImage(
                            content,
                            variables.config.azureEndpoint,
                            variables.config.azureAPIKey
                        );
                        updateResults(results, azureResult);
                        serviceCount++;
                    } catch (any e) {
                        rethrow;
                    }
                } else {
                    throw(type="com.madishetti.aiModeration.ServiceDisabled", 
                          message="Azure Content Moderator is disabled. Please enable it in the configuration to analyze images.");
                }
            }
            
            // If no services are enabled for the content type
            if (serviceCount == 0) {
                if (contentType == "text") {
                    throw(type="com.madishetti.aiModeration.ConfigError", 
                          message="No text moderation services are enabled. Please enable at least one service (Google Perspective or Azure Content Moderator) in the configuration.");
                } else {
                    throw(type="com.madishetti.aiModeration.ConfigError", 
                          message="Azure Content Moderator is disabled. Please enable it in the configuration to analyze images.");
                }
            }
            
            // Calculate final confidence as average of all services
            if (serviceCount > 0) {
                results.confidence = results.confidence / serviceCount;
            }
            
            // Format confidence as percentage with 1 decimal place
            results.confidence = numberFormat(results.confidence * 100, "99.0");
            
            // Return both formatted display and raw data
            return {
                "display": {
                    "Appropriate": results.isAppropriate ? "Yes" : "No",
                    "Confidence": results.confidence & "%",
                    "Flags": arrayToList(results.flags, ", "),
                    "success": results.success
                }
            };
            
        } catch (any e) {
            // Rethrow the error with context
            rethrow;
        }
    }
    
    /**
     * Update overall results with service-specific results
     * 
     * @param struct results Overall results to update
     * @param struct serviceResult Results from a specific service
     */
    private void function updateResults(required struct results, required struct serviceResult) {
        // Update overall appropriateness
        if (!serviceResult.isAppropriate) {
            results.isAppropriate = false;
        }
        
        // Add to confidence total
        results.confidence += serviceResult.confidence;
        
        // Add unique flags
        for (var flag in serviceResult.flags) {
            if (isStruct(flag)) {
                // For Azure flags with severity
                var flagString = flag.category & " (" & flag.severityLevel & ")";
                if (!arrayFind(results.flags, flagString)) {
                    arrayAppend(results.flags, flagString);
                }
            } else {
                // For simple string flags
                if (!arrayFind(results.flags, flag)) {
                    arrayAppend(results.flags, flag);
                }
            }
        }
    }
} 