# AI Content Moderation System

A simple and straight-forward library to setup and manage AI-powered content moderation in Adobe ColdFusion and Lucee, integrating with Google Perspective API and Microsoft Azure Content Safety.

## Features

- **Multi-Service Integration**: Seamlessly integrate with multiple AI services:
  - Google Perspective API for text analysis
  - Azure Content Safety for both text and image analysis
- **Flexible Configuration**: Easy-to-use JSON configuration file
- **Content Type Support**: Analyze both text and images
- **Configurable Thresholds**: Customize moderation sensitivity
- **Raw Results Option**: Access detailed API responses when needed

## Confidence Scoring System

The system implements a unified confidence scoring mechanism that intelligently aggregates results from multiple AI services when enabled:

### Google Perspective API Confidence

- Returns scores from 0 (low risk) to 1 (high risk)
- System inverts these scores to match our confidence scale:
  - 0 risk = 1.0 confidence (100%)
  - 0.5 risk = 0.5 confidence (50%)
  - 1.0 risk = 0.0 confidence (0%)

### Azure Content Safety Confidence

- Uses a severity scale of 0-6:
  - 0 = Safe (100% confidence)
  - 2 = Low severity (66% confidence)
  - 4 = Medium severity (33% confidence)
  - 6 = High severity (0% confidence)
- Confidence is calculated as: `1 - (maxSeverity / 6)`

### Combined Confidence

When multiple services are enabled:
1. Each service provides its own confidence score
2. Scores are averaged to create a final confidence percentage
3. The result is formatted with one decimal place (e.g., "95.5%")

Example confidence calculations:
- Single service (Google): 0.8 risk → 20% confidence
- Single service (Azure): severity 4 → 33% confidence
- Both services: (20% + 33%) / 2 = 26.5% confidence

## Installation

1. Copy the `com` directory to your ColdFusion application's root directory
2. Create a `config` directory in your application root
3. Copy `aiConfig.example.json` to `config/aiConfig.json` and update with your API keys and settings

## Configuration

The system uses a JSON configuration file (`config/aiConfig.json`). Here's an example:

```json
{
    "enableGooglePerspective": true,
    "enableAzureModerator": true,
    "googleAPIKey": "YOUR_GOOGLE_API_KEY",
    "azureEndpoint": "YOUR_AZURE_ENDPOINT",
    "azureAPIKey": "YOUR_AZURE_API_KEY",
    "AzureSeverityThreshold": 2,
    "googlePerspectiveProbabilityThreshold": 0.5,
    "options": {
        "includeRawResults": true
    }
}
```

### Configuration Options

- **Service Enablement**:
  - `enableGooglePerspective`: Enable/disable Google Perspective API
  - `enableAzureModerator`: Enable/disable Azure Content Safety

- **API Credentials**:
  - `googleAPIKey`: Your Google Cloud API key
  - `azureEndpoint`: Azure Content Safety endpoint URL
  - `azureAPIKey`: Azure API key

- **Google Perspective Configuration**:
  - `googlePerspectiveProbabilityThreshold`: Threshold for content moderation (0.0-1.0)
    - Default: 0.5 (50%)
    - Example: If set to 0.5:
      - Content with toxicity score < 0.5 is considered appropriate
      - Content with toxicity score ≥ 0.5 is flagged as inappropriate
    - Affects all Google Perspective attributes:
      - TOXICITY
      - SEVERE_TOXICITY
      - IDENTITY_ATTACK
      - INSULT
      - PROFANITY
      - THREAT
    - The threshold is applied to each attribute independently
    - If any attribute exceeds the threshold, the content is marked in flags
    - The confidence score and Appropriate is calculated based on the TOXICITY attribute score

- **Azure Configuration**:
  - `AzureSeverityThreshold`: Minimum severity level to consider content inappropriate (0-6)
    - Evaluates content across four categories: "Hate", "SelfHarm", "Sexual", and "Violence"
    - Each category is assigned a severity level (0-6) independently
    - The highest severity level across all categories determines the overall severity
    - The overall severity is compared with AzureSeverityThreshold to determine:
      - Confidence score: Calculated as `1 - (maxSeverity / 6)`
      - Appropriate status: Content is marked inappropriate if maxSeverity ≥ AzureSeverityThreshold
    - **Safe (0)**: Content may reference sensitive topics like violence, self-harm, sexual content, or hate speech, but in a professional context (e.g., journalistic, scientific, medical) suitable for most audiences.
    - **Low (2)**: Content may express prejudiced, judgmental, or opinionated views, include offensive language, stereotyping, or low-intensity depictions of harm.
    - **Medium (4)**: Content may use offensive, mocking, or intimidating language towards specific identity groups, depict instructions or fantasies related to harm, or glorify harm at medium intensity.
    - **High (6)**: Content may display explicit and severe harmful instructions, actions, damage, or abuse, including endorsement, glorification, promotion of severe harmful acts, or extreme forms of harm.
    - Example threshold settings:
      - Setting to 2 means content with Low, Medium or higher severity will be flagged
      - Setting to 4 means only Medium and High severity content will be flagged
      - Setting to 6 means only High severity content will be flagged

- **Options**:
  - `includeRawResults`: Include raw API responses in results

## Service Setup Instructions

### Google Perspective API Setup

1. **Create/Select Project**:
   - Visit the [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one from the project dropdown

2. **Enable the API**:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Perspective API"
   - Click "Enable" to activate the API for your project

3. **Create API Key**:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "API Key"
   - Copy the generated API key

4. **Configure API Key** (Optional but recommended):
   - Click on the newly created API key
   - Set application restrictions (HTTP referrers, IP addresses)
   - Set API restrictions to "Perspective API" only
   - Click "Save"

5. **Add to Configuration**:
   - Open your `aiConfig.json`
   - Paste the API key as the value for `googleAPIKey`
   - Save the configuration file

Note: Keep your API key secure and never commit it to version control. Consider using environment variables for production deployments.

### Azure Content Safety Setup

1. **Create Resource**:
   - Visit the [Azure Portal](https://portal.azure.com/)
   - Click "Create a resource"
   - Search for "Content Safety"
   - Click "Create" on the Content Safety resource

2. **Configure Resource**:
   - Select your subscription
   - Create or select a resource group
   - Choose a region close to your users
   - Enter a unique name for your resource
   - Click "Review + create" then "Create"

3. **Get API Credentials**:
   - Once deployment is complete, click "Go to resource"
   - Navigate to "Keys and Endpoint" in the left menu
   - Copy the "Endpoint" URL
   - Copy either "Key 1" or "Key 2"

4. **Add to Configuration**:
   - Open your `aiConfig.json`
   - Add the endpoint URL as `azureEndpoint`
   - Add the key as `azureAPIKey`
   - Save the configuration file

## Usage

### Basic Text Moderation

```cfscript
// Initialize the moderation manager
aiModeration = createObject("component", "com.madishetti.aiModeration.AIModerationManager").init();

// Analyze text content
result = aiModeration.moderateContent(
    content = "Your text content here",
    contentType = "text"
);

// Handle the results
if (result.display.Appropriate == "Yes") {
    writeOutput("Content is appropriate");
} else {
    writeOutput("Content is inappropriate. Flags: " & result.display.Flags);
}
```

### Image Moderation

```cfscript
// Initialize the moderation manager
aiModeration = createObject("component", "com.madishetti.aiModeration.AIModerationManager").init();

// Analyze image content
result = aiModeration.moderateContent(
    content = "imageBase64 Base64 encoded image data",
    contentType = "image"
);

//  Handle the results
if (result.display.Appropriate == "Yes"){
    writeOutput("Image is appropriate");
} else {
    writeOutput("Image is inappropriate. Flags: " & result.display.Flags);
}
```

## Return Format

The moderation system returns a structured response with the following format:

```json
{
    "Appropriate": false,
    "flags": [
        "toxicity",
        "severe_toxicity",
        "insult",
        "profanity",
        "threat",
        "hate (Low)",
        "selfharm (Safe)",
        "sexual (Safe)",
        "violence (Medium)"
    ],
    "success": true,
    "confidence": "18.8"
}
```

### Response Fields

- `Appropriate`: Boolean indicating if the content is appropriate (true) or inappropriate (false)
- `flags`: List of detected issues, including:
  - Google Perspective flags: "toxicity", "severe_toxicity", "insult", "profanity", "threat" - included only when content is inappropriate and these attributes have scores higher than the googlePerspectiveProbabilityThreshold value
  - Azure Content Safety flags: "hate", "selfharm", "sexual", "violence" (with severity level in parentheses) - included for both appropriate and inappropriate content
- `success`: Boolean indicating if the moderation request was successful
- `confidence`: String representing the combined confidence score as a percentage

### Example Responses

#### Inappropriate Content Example
```json
{
    "Appropriate": false,
    "flags": [
        "toxicity",
        "severe_toxicity",
        "insult",
        "profanity",
        "threat",
        "hate (Low)",
        "selfharm (Safe)",
        "sexual (Safe)",
        "violence (Medium)"
    ],
    "success": true,
    "confidence": "18.8"
}
```

#### Appropriate Content Example
```json
{
    "Appropriate": true,
    "flags": [
      "hate (Low)",
      "selfharm (Low)",
      "sexual (Low)",
      "violence (Low)"
    ],
    "success": true,
    "Confidence": "95.5"
}
```