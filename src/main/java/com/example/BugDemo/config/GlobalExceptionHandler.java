package com.example.BugDemo.config;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ControllerAdvice;
import org.springframework.web.bind.annotation.ExceptionHandler;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.StringWriter;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;

@ControllerAdvice
public class GlobalExceptionHandler {

    private static final String OPENAI_API_URL = "https://api.openai.com/v1/chat/completions";

    private final Environment environment;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public GlobalExceptionHandler(Environment environment) {
        this.environment = environment;
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<String> handleAllExceptions(Exception ex) {
        String stackTrace = getStackTrace(ex);
        String aiComment = getAiFixComment(stackTrace);

        String body = """
                An error occurred in the application.

                Exception:
                %s

                Suggested fix comments from AI:
                %s
                """.formatted(stackTrace, aiComment);

        return new ResponseEntity<>(body, HttpStatus.INTERNAL_SERVER_ERROR);
    }

    private String getStackTrace(Throwable throwable) {
        StringWriter sw = new StringWriter();
        PrintWriter pw = new PrintWriter(sw);
        throwable.printStackTrace(pw);
        return sw.toString();
    }

    /**
     * Calls OpenAI's Chat Completions API with the stack trace and
     * returns a string that can be used as "fix comments".
     * <p>
     * Priority for API key lookup:
     * 1) application.yaml property "openai.api-key"
     * 2) environment variable OPENAI_API_KEY
     */
    private String getAiFixComment(String stackTrace) {
        String apiKeyFromProps = environment.getProperty("openai.api-key");
        String apiKeyEnv = System.getenv("OPENAI_API_KEY");

        String apiKey = (apiKeyFromProps != null && !apiKeyFromProps.isBlank())
                ? apiKeyFromProps
                : apiKeyEnv;

        if (apiKey == null || apiKey.isBlank()) {
            return "OpenAI API key is not configured in application.yaml (openai.api-key) or environment variable OPENAI_API_KEY; cannot request AI fix comments.";
        }

        String prompt = """
                You are a senior Java Spring Boot developer.
                You will be given a Java exception stack trace from a Spring MVC controller.
                1. Explain briefly (2-3 sentences) what is most likely causing the error.
                2. Then provide a minimal Java code fix using only Java line comments (starting with //) that could be inserted into the controller or related code.

                Stack trace:
                %s
                """.formatted(stackTrace);

        String requestBody = """
                {
                  "model": "gpt-4.1-mini",
                  "messages": [
                    {
                      "role": "system",
                      "content": "You are a concise Java Spring Boot debugging assistant."
                    },
                    {
                      "role": "user",
                      "content": %s
                    }
                  ],
                  "temperature": 0.2
                }
                """.formatted(toJsonString(prompt));

        HttpClient client = HttpClient.newHttpClient();
        HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(OPENAI_API_URL))
                .header("Content-Type", "application/json")
                .header("Authorization", "Bearer " + apiKey)
                .POST(HttpRequest.BodyPublishers.ofString(requestBody, StandardCharsets.UTF_8))
                .build();

        try {
            HttpResponse<String> response = client.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            int status = response.statusCode();
            if (status >= 200 && status < 300) {
                String body = response.body();
                try {
                    JsonNode root = objectMapper.readTree(body);
                    JsonNode choices = root.path("choices");
                    if (choices.isArray() && !choices.isEmpty()) {
                        JsonNode message = choices.get(0).path("message");
                        String content = message.path("content").asText(null);
                        if (content != null && !content.isBlank()) {
                            return content;
                        }
                    }
                    return "Received AI response but content field was missing or empty. Raw body: " + body;
                } catch (IOException parseException) {
                    return "Received AI response but failed to parse JSON: " + parseException.getMessage() + ". Raw body: " + body;
                }
            } else {
                return "Failed to get AI fix comments. HTTP status: " + status + ", body: " + response.body();
            }
        } catch (Exception e) {
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
            String message = e.getMessage();
            String type = e.getClass().getName();
            if (message == null || message.isBlank()) {
                message = "no error message available; check server logs, network connectivity, and OpenAI API key/configuration";
            }
            return "Error while calling OpenAI API (" + type + "): " + message;
        }
    }

    /**
     * Very small helper to JSON-escape a plain string so it can be embedded
     * as a JSON string literal.
     */
    private String toJsonString(String value) {
        StringBuilder sb = new StringBuilder("\"");
        for (char c : value.toCharArray()) {
            switch (c) {
                case '"' -> sb.append("\\\"");
                case '\\' -> sb.append("\\\\");
                case '\b' -> sb.append("\\b");
                case '\f' -> sb.append("\\f");
                case '\n' -> sb.append("\\n");
                case '\r' -> sb.append("\\r");
                case '\t' -> sb.append("\\t");
                default -> {
                    if (c < 0x20) {
                        sb.append(String.format("\\u%04x", (int) c));
                    } else {
                        sb.append(c);
                    }
                }
            }
        }
        sb.append("\"");
        return sb.toString();
    }
}

