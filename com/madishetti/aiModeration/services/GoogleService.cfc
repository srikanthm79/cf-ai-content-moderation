/**
 * GoogleService.cfc
 * 
 * Service component for Google Perspective API integration
 * 
 * @author Srikanth Madishetti
 * @version 1.0.0
 */
component {
    // Configuration variables
    variables.config = {};

    /**
     * Constructor
     */
    public function init(required struct config) {
        variables.config = arguments.config;
        return this;
    }
    
    /**
     * Analyze text with Google Perspective API
     * 
     * @param string text The text to analyze
     * @param string language The language code (defaults to "en")
     * @return struct Standardized results from Google
     */
    public struct function analyzeText(required string text) {
        var apiUrl = "https://commentanalyzer.googleapis.com/v1alpha1/comments:analyze?key=#variables.config.googleAPIKey#";
        var payload = {
            "comment": {
                "text": text
            },
            "requestedAttributes": {
                "TOXICITY": {},
                "SEVERE_TOXICITY": {},
                "IDENTITY_ATTACK": {},
                "INSULT": {},
                "PROFANITY": {},
                "THREAT": {}
            }
        };
        
        // Use Lucee-specific HTTP component if on Lucee to remove url encoding, otherwise use standard cfhttp
        if (server.coldfusion.productName contains "Lucee") {
            var httpService = new httpLuceeNoEncoding();
            var response = httpService.makeLuceeHTTPWithNoEncoding(
                url=apiUrl,
                method="POST",
                headers={"Content-Type": "application/json"},
                body=serializeJSON(payload)
            );
        } else {
            cfhttp(url=apiUrl, method="POST", result="response", charset="utf-8") {
                cfhttpparam(type="header", name="Content-Type", value="application/json");
                cfhttpparam(type="body", value=serializeJSON(payload));
            }
        }
        
        if (response.responseHeader.status_code != 200) {
            throw(type="com.madishetti.aiModeration.GoogleAPIError", 
                  message="Google API returned error: #response.responseHeader.status_code#", 
                  detail=response.fileContent);
        }
     
        var result = deserializeJSON(response.fileContent);
        
        // Standardize the response
        return {
            "success": true,
            "isAppropriate": result.attributeScores.TOXICITY.summaryScore.value < (variables.config.googlePerspectiveProbabilityThreshold ?: 0.5),
            // Invert the confidence score because:
            // Google Perspective API returns 0 (low risk) to 1 (high risk)
            // But AI Moderation Manager expects 0 (low confidence) to 1 (high confidence)
            "confidence": 1 - result.attributeScores.TOXICITY.summaryScore.value,
            "flags": getFlags(result.attributeScores)
        };
    }
    
    /**
     * Extract flags from Google Perspective API results
     * 
     * @param struct attributeScores Attribute scores from Google
     * @return array Array of content flags
     */
    private array function getFlags(required struct attributeScores) {
        var flags = [];
        var threshold = variables.config.googlePerspectiveProbabilityThreshold ?: 0.5;
        
        if (attributeScores.TOXICITY.summaryScore.value >= threshold) {
            flags.append("toxicity");
        }
        
        if (attributeScores.SEVERE_TOXICITY.summaryScore.value >= threshold) {
            flags.append("severe_toxicity");
        }
        
        if (attributeScores.IDENTITY_ATTACK.summaryScore.value >= threshold) {
            flags.append("identity_attack");
        }
        
        if (attributeScores.INSULT.summaryScore.value >= threshold) {
            flags.append("insult");
        }
        
        if (attributeScores.PROFANITY.summaryScore.value >= threshold) {
            flags.append("profanity");
        }
        
        if (attributeScores.THREAT.summaryScore.value >= threshold) {
            flags.append("threat");
        }
        
        return flags;
    }
} 