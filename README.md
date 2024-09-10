# ChatAI

ChatAI project provides a unified terminal and text editor interface for AI chats, supporting multiple APIs including OpenAI, Anthropic, and Groq.

## Features

- Extremeley lightweight, using a single python script.
- Support for multiple AI models (GPT, Claude, Llama, Mixtral)
- Customizable system prompts and chat history
- Temperature control for response generation
- Easy-to-use installation script

## Installation

1. Clone the repository:
   ```
   git clone https://github.com/trrt-good/ChatAI.git
   cd ChatAI
   ```

2. Run the installation script:
   ```
   ./install.sh
   ```

3. Follow the prompts to select your terminal and text editor.

4. Add your API keys to `config.json`:
   ```json
   {
     "api_keys": {
       "anthropic": "your_anthropic_key",
       "openai": "your_openai_key",
       "groq": "your_groq_key"
     }
   }
   ```

5. (Recommended) Set up a hotkey in your desktop environment or operating system to run the chatai.sh script, so you can launch a terminal with a new chat easily.

## Usage

1. Launch the chat interface using the created script or your configured hotkey.

2. Write your messages in the opened text editor.

3. Basic usage:
   - Simply type your message and save the file and press Alt+I to generate a response.
   - If no message markers are used, the entire file content is treated as a user message.

4. Advanced usage with message markers:
   ```
   # System
   You are a helpful assistant.
   You do what you are told.

   # User
   Hello, can you help me with a task?

   # Assistant
   Certainly! I'd be happy to help you with your task. What do you need assistance with?

   # User
   [Your message here]
   ```

5. Press Alt+I to generate a response from the AI.

6. The file will be refreshed with the new message.

### Additional Features

- **Model Selection**: Optionally specify a model at the top of the file:
  ```
  !model:gpt4
  ```

- **Temperature Control**: Optionally set the temperature for response generation:
  ```
  !temp:0.7
  ```

- **Automatic Regeneration**: If the last message in the file is an assistant response, pressing Alt+I will just regenerate that response.

- **Commenting**: You can add comments to your chat file that will be ignored by the AI:
  - Multiline comments: `<!-- Your comment here -->`, but configurable in `config.json`
  - Single-line comments: Configurable in `config.json`

## Configuration

All settings are customizable in `config.json`:

```json
{
    "model_map": {
      "opus": "claude-3-opus-20240229",
      "sonnet": "claude-3-5-sonnet-20240620",
      "haiku": "claude-3-haiku-20240307",
      "gpt3.5": "gpt-3.5-turbo",
      "gpt4": "gpt-4-turbo-preview",
      "gpt4-1106": "gpt-4-1106-preview",
      "gpt4o": "gpt-4o",
      "gpt4o-mini": "gpt-4o-mini",
      "llama8b": "llama-3.1-8b-instant",
      "llama70b": "llama-3.1-70b-versatile",
      "llama405b": "llama-3.1-405b-reasoning",
      "mixtral": "mixtral-8x7b-32768"
    },
    "api_keys": {
      "anthropic": "your_anthropic_key",
      "openai": "your_openai_key",
      "groq": "your_groq_key"
    },
    "default_model": "llama70b",
    "default_temperature": 0.0,
    "metadata_markers": {
      "model": "!model:",
      "temp": "!temp:"
    },
    "message_markers": {
      "system": "# System",
      "user": "# User",
      "assistant": "# Assistant"
    },
    "comment_markers": {
      "multiline_start": "<!--",
      "multiline_end": "-->",
      "singleline": ""
    }
}
```

- `model_map`: Define shorthand names for models
- `api_keys`: Set your API keys for each service
- `default_model`: Set the default AI model
- `default_temperature`: Set the default temperature for response generation
- `metadata_markers`: Customize markers for model and temperature settings
- `message_markers`: Customize markers for different message types
- `comment_markers`: Define comment syntax (multiline and single-line)

## Contributing

We welcome contributions to expand support for more terminals and text editors:

1. Fork the repository
2. Create a new directory under `terminal_integration/[terminal]/[editor]/`
3. Add the necessary integration files (e.g., `init.lua` for Micro)
4. Update `install.sh` to include the new terminal/editor combination
5. Submit a pull request with your changes

## Troubleshooting

- Check the log file at `logs/chatai.log` for error messages
- Ensure your API keys are correctly set in `config.json`
- Verify that your selected terminal and text editor are properly installed

## License

This project is licensed under the MIT License - see the LICENSE file for details.
