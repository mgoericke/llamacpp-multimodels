package de.javamark.demo.ai.control;

import io.quarkiverse.langchain4j.RegisterAiService;

@RegisterAiService
public interface MyAgent {
    String chat(String userMessage);
}
