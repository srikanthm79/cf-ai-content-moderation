<cfscript>
    // Initialize the AI Moderation Manager
    aiModeration = createObject("component", "com.madishetti.aiModeration.AIModerationManager").init();
    
    // Check if Azure is configured
    configPath = expandPath("config/aiConfig.json");
    defaultConfig = deserializeJSON(fileRead(configPath));
    isAzureEnabled = defaultConfig.enableAzureModerator;
    
    // Test text content
    testTexts = [
        "This is a normal, friendly message.",
        "I hate you and want to kill you!",
        "Let's meet up for coffee tomorrow.",
        "You're a stupid idiot who should die!",
        "Hallo, wie geht es"
    ];
    
    // Test image paths
    testImages = [
        "test/images/appropriate.jpg",
        "test/images/violent.jpg",
        "test/images/weapon.jpg"
    ];
</cfscript>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Content Moderation Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        .test-section {
            margin-bottom: 40px;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .result {
            margin: 10px 0;
            padding: 10px;
            border-radius: 5px;
        }
        .appropriate {
            background-color: #d4edda;
            color: #155724;
        }
        .inappropriate {
            background-color: #f8d7da;
            color: #721c24;
        }
        .image-container {
            display: flex;
            flex-wrap: wrap;
            gap: 20px;
            margin: 20px 0;
        }
        .image-result {
            width: 300px;
            border: 1px solid #ddd;
            padding: 10px;
            border-radius: 5px;
            position: relative;
        }
        .image-result img {
            width: 100%;
            height: auto;
            margin-bottom: 10px;
        }
        .flags {
            margin-top: 10px;
            font-size: 0.9em;
        }
        .flag {
            display: inline-block;
            background-color: #f0f0f0;
            padding: 2px 6px;
            margin: 2px;
            border-radius: 3px;
            font-size: 0.8em;
        }
        .loading {
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: rgba(255, 255, 255, 0.9);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 1000;
            flex-direction: column;
            text-align: center;
            padding: 20px;
        }
        .loading-text {
            margin-top: 15px;
            font-size: 1.2em;
            color: #333;
        }
        .loading-fun-fact {
            margin-top: 10px;
            font-size: 0.9em;
            color: #666;
            font-style: italic;
        }
        .spinner {
            width: 50px;
            height: 50px;
            border: 5px solid #f3f3f3;
            border-top: 5px solid #3498db;
            border-radius: 50%;
            animation: spin 1s linear infinite;
        }
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        .raw-results {
            margin-top: 10px;
            padding: 10px;
            background-color: #f8f9fa;
            border-radius: 5px;
            font-family: monospace;
            font-size: 0.9em;
            white-space: pre-wrap;
            word-wrap: break-word;
            max-height: 200px;
            overflow-y: auto;
        }
        .toggle-raw {
            margin-top: 10px;
            padding: 5px 10px;
            background-color: #e9ecef;
            border: none;
            border-radius: 3px;
            cursor: pointer;
            font-size: 0.8em;
        }
        .toggle-raw:hover {
            background-color: #dee2e6;
        }
        .raw-hidden {
            display: none;
        }
        .warning {
            background-color: #fff3cd;
            color: #856404;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            border: 1px solid #ffeeba;
        }
        .warning strong {
            display: block;
            margin-bottom: 5px;
        }
        .debug {
            background-color: #f8f9fa;
            border: 1px solid #ddd;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            font-family: monospace;
            font-size: 0.9em;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        #initialLoading {
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background: #ffffff;
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 9999;
            flex-direction: column;
            text-align: center;
            padding: 20px;
            transition: opacity 0.5s ease-out;
        }
        
        #initialLoading.fade-out {
            opacity: 0;
            pointer-events: none;
        }
        
        .loading-content {
            max-width: 600px;
            padding: 30px;
            background: #f8f9fa;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }
        
        .loading-title {
            font-size: 2em;
            color: #2c3e50;
            margin-bottom: 20px;
        }
        
        .loading-message {
            font-size: 1.2em;
            color: #34495e;
            margin-bottom: 15px;
        }
        
        .loading-fun-fact {
            font-size: 1em;
            color: #7f8c8d;
            font-style: italic;
            margin-top: 20px;
            padding: 10px;
            background: #ecf0f1;
            border-radius: 5px;
        }
        
        .loading-spinner {
            width: 60px;
            height: 60px;
            border: 6px solid #f3f3f3;
            border-top: 6px solid #3498db;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin: 20px auto;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
    </style>
</head>
<body>
    <cfprocessingdirective pageencoding="UTF-8">
   
    <cfoutput>
     <H2>Server: #server.coldfusion.productName# - #server.coldfusion.productVersion#</h2>
    </cfoutput>
    <div id="initialLoading">
        <div class="loading-content">
            <div class="loading-spinner"></div>
            <h2 class="loading-title">🤖 CFCAMP AI Content Moderation</h2>
            <p class="loading-message">AI bots are warming up their circuits...</p>
            <div class="loading-fun-fact">
                <cfset funFacts = [
                    "Did you know? The first CFCAMP was held in 2008! 🎉",
                    "The CFML community is one of the friendliest in tech! 💖",
                    "CFCAMP is where CF superheroes gather to save the web! 🦸‍♂️",
                    "CFCAMP: Where CF developers come to geek out! 🚀",
                    "The best part of CFCAMP? The community! 💪"
                ]>
                <cfoutput>#funFacts[randRange(1, arrayLen(funFacts))]#</cfoutput>
            </div>
        </div>
    </div>
    <cfflush />

    <h1>AI Content Moderation Test</h1>
    
    <div class="test-section">
        <h2>Text Moderation Test</h2>
        <cfoutput>
            <cfloop array="#testTexts#" index="text">
                <cfset result = aiModeration.moderateContent(text, "text")>
                <div class="result #result.display.Appropriate ? 'appropriate' : 'inappropriate'#">
                    <p><strong>Text:</strong> #text#</p>
                    <p><strong>Appropriate:</strong> #result.display.Appropriate#</p>
                    <p><strong>Confidence:</strong> #result.display.Confidence#</p>
                    <div class="flags">
                        <strong>Flags:</strong>
                        <cfloop list="#result.display.Flags#" index="flag" delimiters=",">
                            <span class="flag">#trim(flag)#</span>
                        </cfloop>
                    </div>
                    <button class="toggle-raw" onclick="toggleRaw(this)">Show Raw Results</button>
                    <div class="raw-results raw-hidden">
                        <pre>#serializeJSON(result)#</pre>
                    </div>
                </div>
            </cfloop>
        </cfoutput>
    </div>
    
    <div class="test-section">
        <h2>Image Moderation Test</h2>
        <cfif not isAzureEnabled>
            <div class="warning">
                <strong>Azure Content Safety Not Enabled</strong>
                <p>Image moderation requires Azure Content Safety to be enabled. Please check your configuration in <code>config/aiConfig.json</code>:</p>
                <ul>
                    <li>Set <code>"enableAzureModerator": true</code> in your configuration</li>
                </ul>
            </div>
        <cfelse>
            <div class="image-container">
                <cfoutput>
                    <cfloop array="#testImages#" index="imagePath">
                        <cfif fileExists(expandPath(imagePath))>
                            <cfset imageFile = fileReadBinary(expandPath(imagePath))>
                            <cfset base64Image = binaryEncode(imageFile, "base64")>
                            
                            <div class="image-result">
                                <img src="data:image/jpeg;base64,#base64Image#" alt="Test Image">
                                <p><strong>Image:</strong> #listLast(imagePath, "/")#</p>
                                <cftry>
                                    <cfset result = aiModeration.moderateContent(base64Image, "image")>
                                    <script>
                                        // Remove loading indicator after moderation is complete
                                        document.currentScript.parentElement.querySelector('.loading').style.display = 'none';
                                        // Add appropriate/inappropriate class
                                        document.currentScript.parentElement.classList.add('#result.display.appropriate ? 'appropriate' : 'inappropriate'#');
                                    </script>
                                    <p><strong>Appropriate:</strong> #result.display.Appropriate#</p>
                                    <p><strong>Confidence:</strong> #result.display.Confidence#</p>
                                    <div class="flags">
                                        <strong>Flags:</strong>
                                        <cfloop list="#result.display.Flags#" index="flag" delimiters=",">
                                            <span class="flag">#trim(flag)#</span>
                                        </cfloop>
                                    </div>
                                    <button class="toggle-raw" onclick="toggleRaw(this)">Show Raw Results</button>
                                    <div class="raw-results raw-hidden">
                                        <pre>#serializeJSON(result)#</pre>
                                    </div>
                                <cfcatch type="any">
                                  <cfdump var="#cfcatch#">
                                    <div class="warning">
                                        <strong>Exception:</strong> #cfcatch.message#
                                        <div class="debug">
                                            <strong>Exception Details:</strong>
                                            <pre>#serializeJSON({
                                                "message": cfcatch.message,
                                                "detail": cfcatch.detail,
                                                "type": cfcatch.type,
                                                "stackTrace": cfcatch.stackTrace
                                            })#</pre>
                                        </div>
                                    </div>
                                </cfcatch>
                                </cftry>
                            </div>
                        </cfif>
                    </cfloop>
                </cfoutput>
            </div>
        </cfif>
    </div>

    <script>
        document.addEventListener('DOMContentLoaded', function() {
            const loadingScreen = document.getElementById('initialLoading');
            loadingScreen.classList.add('fade-out');
            setTimeout(() => {
                loadingScreen.style.display = 'none';
            }, 500);
        });
        
        function toggleRaw(button) {
            const rawResults = button.nextElementSibling;
            if (rawResults.classList.contains('raw-hidden')) {
                rawResults.classList.remove('raw-hidden');
                button.textContent = 'Hide Raw Results';
            } else {
                rawResults.classList.add('raw-hidden');
                button.textContent = 'Show Raw Results';
            }
        }
    </script>
</body>
</html> 