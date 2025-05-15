/**
 * AzureService.cfc
 * 
 * Service component for Azure Content Safety integration
 * 
 * @author Srikanth Madishetti
 * @version 1.0.0
 */
component {
    // Configuration variables
    variables.config = {};
    variables.azureEndpoint = "";
    variables.azureAPIKey = "";

    /**
     * Constructor
     */
    public function init(required struct config) {
        variables.config = arguments.config;
        variables.azureEndpoint = variables.config.azureEndpoint;
        variables.azureAPIKey = variables.config.azureAPIKey;
        variables.azureSeverityThreshold = variables.config.azureSeverityThreshold ?: 2;
        return this;
    }
    
    /**
     * Analyze text with Azure Content Safety
     * 
     * @param string text The text to analyze
     * @return struct Standardized results from Azure
     */
    public struct function analyzeText(required string text) {
        var azureAPI = variables.azureEndpoint & "/contentsafety/text:analyze?api-version=2023-10-01";
        
        var payload = {
            "text": text,
            "categories": ["Hate", "SelfHarm", "Sexual", "Violence"],
            "blocklistNames": [],
            "haltOnBlocklistHit": false,
            "outputType": "FourSeverityLevels"
        };
        
        cfhttp(url=azureAPI, method="POST", result="response") {
            cfhttpparam(type="header", name="Ocp-Apim-Subscription-Key", value=variables.azureAPIKey);
            cfhttpparam(type="header", name="Content-Type", value="application/json");
            cfhttpparam(type="body", value=serializeJSON(payload));
        }
        
        if (response.responseHeader.status_code != 200) {
            throw(type="com.madishetti.aiModeration.AzureError", 
                  message="Azure API returned error: #response.responseHeader.status_code#", 
                  detail=response.fileContent);
        }
       
        var result = deserializeJSON(response.fileContent);
        
        // Standardize the response
        return {
            "success": true,
            "isAppropriate": !hasInappropriateContent(result),
            "confidence": calculateConfidence(result),
            "flags": getFlags(result)
        };
    }
    
    /**
     * Analyze image with Azure Content Safety
     * 
     * @param string imageBase64 Base64 encoded image data
     * @return struct Standardized results from Azure
     */
    public struct function analyzeImage(required string imageBase64) {
        var azureAPI = variables.azureEndpoint & "/contentsafety/image:analyze?api-version=2023-10-01";
        
        var payload = {
            "image": {
                "content": imageBase64
            },
            "categories": ["Hate", "SelfHarm", "Sexual", "Violence"],
            "outputType": "FourSeverityLevels"
        };
        
        cfhttp(url=azureAPI, method="POST", result="response") {
            cfhttpparam(type="header", name="Ocp-Apim-Subscription-Key", value=variables.azureAPIKey);
            cfhttpparam(type="header", name="Content-Type", value="application/json");
            cfhttpparam(type="body", value=serializeJSON(payload));
        }
        
        if (response.responseHeader.status_code != 200) {
            throw(type="com.madishetti.aiModeration.AzureError", 
                  message="Azure API returned error: #response.responseHeader.status_code#", 
                  detail=response.fileContent);
        }
        
        var result = deserializeJSON(response.fileContent);
        
        // Standardize the response
        return {
            "success": true,
            "isAppropriate": !hasInappropriateContent(result),
            "confidence": calculateConfidence(result),
            "flags": getFlags(result)
        };
    }
    
    /**
     * Check if content has inappropriate categories based on severity threshold
     * 
     * @param struct result Results from Azure
     * @return boolean True if content is inappropriate
     */
    private boolean function hasInappropriateContent(required struct result) {
        var maxSeverity = 0;
        
        // Check each category's severity
        for (var analysis in result.categoriesAnalysis) {
            var severity = analysis.severity;
            if (severity > maxSeverity) {
                maxSeverity = severity;
            }
        }
        
        // Content is inappropriate if any category exceeds the threshold
        return maxSeverity >= variables.azureSeverityThreshold;
    }
    
    /**
     * Calculate confidence score from Azure Content results
     * 
     * The function calculates confidence based on the following logic:
     * 
     * Initial Check:
     * - If there's no categories analysis, return 0 confidence
     * 
     * Severity Collection:
     * - maxSeverity: Tracks the highest severity found across all categories
     * 
     * Severity Normalization:
     * Azure's severity scale is 0-6:
     * - 0 = Safe
     * - 2 = Low
     * - 4 = Medium
     * - 6 = High
     * 
     * normalizedMaxSeverity: Converts the max severity to a 0-1 scale by dividing by 6
     * This becomes our confidence score directly
     * 
     * @param struct result The Azure Content Moderator API response
     * @return numeric Confidence score between 0 and 1
     */
    private numeric function calculateConfidence(required struct result) {
        if (!structKeyExists(result, "categoriesAnalysis")) {
            return 0;
        }
        
        var maxSeverity = 0;
        var allSafe = true;
        
        for (var analysis in result.categoriesAnalysis) {
            var severity = analysis.severity;
            if (severity > maxSeverity) {
                maxSeverity = severity;
            }
            if (severity > 0) {
                allSafe = false;
            }
        }
        
        // If all categories are Safe (severity 0), return high confidence
        if (allSafe) {
            return 1.0;
        }
        
        // Invert the confidence score because:
        // AI Moderation Manager expects 0 (low confidence) to 1 (high confidence)
        var normalizedMaxSeverity = 1 - (maxSeverity / 6);
        
        return normalizedMaxSeverity;
    }
    
    /**
     * Extract flags from Azure analysis results
     * 
     * @param struct result Results from Azure
     * @return array Array of content flags with severity
     */
    private array function getFlags(required struct result) {
        var flags = [];
        
        if (!structKeyExists(result, "categoriesAnalysis")) {
            return flags;
        }
        
        for (var analysis in result.categoriesAnalysis) {
            var flagString = lcase(analysis.category) & " (" & getSeverityLevel(analysis.severity) & ")";
            flags.append(flagString);
        }
        
        return flags;
    }
    
    /**
     * Get human-readable severity level
     * 
     * @param numeric severity Severity score
     * @return string Human-readable severity level
     */
    private string function getSeverityLevel(required numeric severity) {
        switch(severity) {
            case 0:
                return "Safe";
            case 2:
                return "Low";
            case 4:
                return "Medium";
            case 6:
                return "High";
            default:
                return "Unknown";
        }
    }
} 