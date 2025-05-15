/**
 * httpLuceeNoEncoding.cfc
 * 
 * Service component for handling HTTP requests in Lucee with no URL encoding
 * 
 * @author Srikanth Madishetti
 * @version 1.0.0
 */
component {
    /**
     * Make HTTP request in Lucee with no URL encoding
     * 
     * @param string url The URL to call
     * @param string method The HTTP method (defaults to "POST")
     * @param struct headers The HTTP headers to send
     * @param any body The request body
     * @return struct The response from the HTTP call
     */
    public struct function makeLuceeHTTPWithNoEncoding(
        required string url,
        string method="POST",
        struct headers={},
        any body=""
    ) {
        var response = {};
        
        cfhttp(url=arguments.url, 
               method=arguments.method, 
               result="response", 
               charset="utf-8", 
               encodeurl=false) {
            
            // Add headers
            for (var header in arguments.headers) {
                cfhttpparam(type="header", name=header, value=arguments.headers[header]);
            }
            
            // Add body if provided
            if (isDefined("arguments.body") && len(arguments.body)) {
                cfhttpparam(type="body", value=arguments.body);
            }
        }
        
        return response;
    }
} 