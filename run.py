import argparse
import json
import os
import logging
from typing import Dict, List, Tuple
import anthropic
from groq import Groq
from openai import OpenAI
import base64
import vertexai
from vertexai.generative_models import GenerativeModel, Part, SafetySetting, Content
import re
import pathlib

script_directory = os.path.dirname(os.path.realpath(__file__))
if not os.path.exists(os.path.join(script_directory,'history')):
    os.makedirs(os.path.join(script_directory,'history'))
if not os.path.exists(os.path.join(script_directory,'logs')):
    os.makedirs(os.path.join(script_directory,'logs'))
pathlib.Path(os.path.join(script_directory, 'logs', "chatai.log")).touch()

# Set up logging
logging.basicConfig(level=logging.INFO, # switch between logging.DEBUG and logging.INFO
                    format='%(asctime)s - %(levelname)s - %(message)s',
                    filename=os.path.join(script_directory, 'logs', 'chatai.log'),
                    filemode='a')
logger = logging.getLogger(__name__)

def load_config(config_path: str = os.path.join(script_directory, 'config.json')) -> Dict:
    logger.info(f"Loading configuration from {config_path}")
    try:
        with open(config_path, 'r') as config_file:
            config = json.load(config_file)
        logger.debug(f"Configuration loaded successfully: {config}")
        return config
    except FileNotFoundError:
        logger.error(f"Configuration file not found: {config_path}")
        raise
    except json.JSONDecodeError:
        logger.error(f"Invalid JSON in configuration file: {config_path}")
        raise

def initialize_clients(config: Dict) -> Tuple[anthropic.Anthropic, OpenAI, Groq]:
    logger.info("Initializing API clients")
    vertexai.init(project="trusty-vim-432923-r6", location="us-central1")
    try:
        return (
            anthropic.Anthropic(api_key=os.getenv('ANTHROPIC_API_KEY') or config['api_keys']['anthropic']),
            OpenAI(api_key=os.getenv('OPENAI_API_KEY') or config['api_keys']['openai']),
            Groq(api_key=os.getenv('GROQ_API_KEY') or config['api_keys']['groq']),
        )
    except KeyError as e:
        logger.error(f"Missing API key in configuration: {e}")
        raise

def parse_messages(filename: str, config: Dict) -> Tuple[str, List[Dict[str, str]], float, str]:
    logger.info(f"Parsing messages from file: {filename}")
    try:
        with open(filename, "r", encoding='utf-8') as file:
            content = file.read()
        
        # Extract model and temperature from metadata
        metadata_markers = config.get('metadata_markers', {
            'model': '!model:',
            'temp': '!temp:'
        })
        model = None
        temp = None
        for line in content.split('\n')[:2]:  # Check only first two lines
            if line.startswith(metadata_markers['model']):
                model = line[len(metadata_markers['model']):].strip()
            elif line.startswith(metadata_markers['temp']):
                temp = float(line[len(metadata_markers['temp']):].strip())
        
        model = config['model_map'].get(model or config['default_model'], model or config['default_model'])
        temp = temp if temp is not None else config['default_temperature']
        
        # Parse messages
        message_markers = config.get('message_markers', {
            'system': '# System',
            'user': '# User',
            'assistant': '# Assistant'
        })
        reverse_markers = {v: k for k, v in message_markers.items()}
        
        messages = []
        current_role, current_content = None, []

        lines = content.split('\n')
        has_markers = any(line.startswith(tuple(reverse_markers)) for line in lines)
        
        if not has_markers:
            # If no markers are found, treat the entire content as a user message
            logger.info("No markers found. Treating entire content as user message.")
            return "", [{"role": "user", "content": content.strip()}], temp, model
        
        for line in lines:
            marker = next((m for m in reverse_markers if line.startswith(m)), None)
            if marker:
                if current_role:
                    messages.append({"role": current_role, "content": "\n".join(current_content).strip()})
                current_role = reverse_markers[marker]
                current_content = []
            elif current_role:
                current_content.append(line)
        
        if current_role and current_content:
            messages.append({"role": current_role, "content": "\n".join(current_content).strip()})
        
        system_prompt = next((msg["content"] for msg in messages if msg["role"] == "system"), "")
        messages = [msg for msg in messages if msg["role"] != "system"]
        
        logger.info(f"Parsed messages: System prompt, {len(messages)} messages, temp={temp}, model={model}")
        logger.debug(f"System prompt: {system_prompt}")
        logger.debug(f"Messages: {messages}")
        logger.debug(f"Temperature: {temp}")
        logger.debug(f"Model: {model}")
        
        return system_prompt, messages, temp, model
    except Exception as e:
        logger.error(f"Error parsing messages: {e}")
        raise

def remove_comments(content: str, comment_markers: Dict) -> str:
    multiline_start = comment_markers['multiline_start']
    multiline_end = comment_markers['multiline_end']
    singleline = comment_markers['singleline']

    # Remove multiline comments
    if multiline_start and multiline_end:
        content = re.sub(rf'{multiline_start}.*?{multiline_end}', '', content, flags=re.DOTALL)

    # Remove single line comments
    if singleline:
        content = re.sub(rf'{singleline}.*$', '', content, flags=re.MULTILINE)

    return content

def generate_response(system_prompt: str, messages: List[dict], model: str, temp: float,
                      clients: Tuple[anthropic.Anthropic, OpenAI, Groq], config: Dict) -> str:
    logger.info(f"Generating response using model: {model}, temperature: {temp}")
    anthropic_client, openai_client, groq_client = clients

    try:
        if model.startswith("gpt"):
            logger.info("Using OpenAI API")
            response = openai_client.chat.completions.create(
                model=model,
                messages=[{"role": "system", "content": system_prompt}] + messages,
                temperature=temp,
                max_tokens=4096
            )
            return response.choices[0].message.content.strip()
        elif model.startswith("o1"):
            logger.info("Using OpenAI API for Reasoning Model")
            response = openai_client.chat.completions.create(
                model=model,
                messages=messages,
            )
            return response.choices[0].message.content.strip()
        elif model.startswith(("llama", "mixtral")):
            logger.info("Using Groq API")
            response = groq_client.chat.completions.create(
                model=model,
                messages=[{"role": "system", "content": system_prompt}] + messages,
                temperature=temp,
                max_tokens=4096
            )
            return response.choices[0].message.content.strip()
        elif model.startswith(("gemini")):
            google_model = GenerativeModel(model, system_instruction=[system_prompt])
            Content(role="user",)
            history = []
            for message in messages[:-1]:
                history.append(Content(role=("user" if message["role"] == "user" else "model"), parts=[Part.from_text(message["content"])]))   
            chat = google_model.start_chat(history=history)
            response = chat.send_message(
                content=[messages[-1]["content"]], 
                generation_config = {
                    "max_output_tokens": 8192,
                    "temperature": temp,
                    "top_p": 0.95,
                },
                stream=False)
            return response.text
    
        else:  # Assume Anthropic model
            logger.info("Using Anthropic API")
            response = anthropic_client.messages.create(
                model=model,
                max_tokens=4096,
                temperature=temp,
                system=system_prompt,
                messages=messages
            )
            return response.content[0].text.strip()
    except Exception as e:
        logger.error(f"Error generating response: {e}")
        raise
    
def save_messages(filename: str, system_prompt: str, messages: List[dict], 
                  response: str, temp: float, model: str, config: dict) -> None:
    logger.info(f"Saving messages to file: {filename}")
    try:
        with open(filename, 'w', encoding='utf-8') as file:
            file.write(f"!model:{model}\n!temp:{temp}\n")
            file.write(f"{config["message_markers"]["system"]}\n{system_prompt}\n\n")
            for message in messages:
                if message['role'] == "user":
                    file.write(f"{config["message_markers"]["user"]}\n{message['content']}\n\n")
                else:
                    file.write(f"{config["message_markers"]["assistant"]}\n{message['content']}\n\n")
            file.write(f"{config["message_markers"]["assistant"]}\n{response}\n")
        logger.info("Messages saved successfully")
    except Exception as e:
        logger.error(f"Error saving messages: {e}")
        raise

def process_messages(system_prompt, messages, config):
    # Remove last message if its an assistant one
    if messages and messages[-1]['role'] == 'assistant':
        messages.pop()

    # Remove comments
    comment_markers = config.get('comment_markers', {
        'multiline_start': '',
        'multiline_end': '',
        'singleline': ''
    })
    messages = [
        {
            "role": msg["role"],
            "content": remove_comments(msg["content"], comment_markers)
        }
        for msg in messages
    ]
    system_prompt = remove_comments(system_prompt, comment_markers)
    system_prompt = process_system_prompt_template(system_prompt, config)
    return system_prompt, messages
    
def parse_variables(variable_string: str) -> Dict[str, str]:
    """Parse variables from the format 'VAR1="value1",VAR2="value2"'"""
    if not variable_string:
        return {}
    
    variables = {}
    # Match patterns like: VAR="value" or VAR="value with spaces"
    pattern = r'(\w+)\s*=\s*"([^"]*)"'
    matches = re.findall(pattern, variable_string)
    
    for var_name, var_value in matches:
        variables[var_name] = var_value
    return variables

def load_prompt_template(template_name: str) -> str:
    """Load a prompt template from the prompts directory"""
    prompt_path = os.path.join(script_directory, 'prompts', template_name)
    try:
        with open(prompt_path, 'r', encoding='utf-8') as file:
            return file.read().strip()
    except FileNotFoundError:
        logger.error(f"Prompt template not found: {prompt_path}")
        raise
    except Exception as e:
        logger.error(f"Error reading prompt template: {e}")
        raise

def process_system_prompt_template(system_prompt: str, config: Dict) -> str:
    """Process a system prompt that may contain a template directive"""
    use_prompt_marker = config['use_prompt_marker']
    var_start = config['prompt_variable_markers']['start']
    var_end = config['prompt_variable_markers']['end']
    
    # Check if the system prompt contains a template directive
    if not system_prompt.strip().startswith(use_prompt_marker):
        return system_prompt
    
    try:
        # Extract template name and variables
        template_line = system_prompt.strip().split('\n')[0]
        marker_content = template_line[len(use_prompt_marker):].strip()
        
        # Split into template name and variable string
        template_parts = marker_content.split('(', 1)
        template_name = template_parts[0].strip()
        variable_string = template_parts[1].rstrip(')') if len(template_parts) > 1 else ""
        
        # Load the template
        template_content = load_prompt_template(template_name)
        
        # Parse variables
        variables = parse_variables(variable_string)
        
        # Replace variables in template
        for var_name, var_value in variables.items():
            placeholder = f"{var_start}{var_name}{var_end}"
            template_content = re.sub(placeholder, var_value, template_content, flags=re.IGNORECASE)
        
        # Check for any remaining unreplaced variables
        remaining_vars = re.findall(f"{re.escape(var_start)}.*?{re.escape(var_end)}", template_content)
        if remaining_vars:
            logger.warning(f"Unreplaced variables in template: {remaining_vars}")
        
        return template_content
        
    except Exception as e:
        logger.error(f"Error processing prompt template: {e}")
        raise



def main():
    parser = argparse.ArgumentParser(description="Generate a response using the specified model and temperature.")
    parser.add_argument("file", help="Path to the messages file")
    args = parser.parse_args()
    
    logger.info("Starting script execution")

    try:
        config = load_config()
        clients = initialize_clients(config)
        
        logger.info("Parsing messages")
        system_prompt, messages, temp, model = parse_messages(args.file, config)
        logger.info("Processing messages")
        processed_system_prompt, processed_messages = process_messages(system_prompt, messages, config)
        
        response = generate_response(processed_system_prompt, processed_messages, model, temp, clients, config)
        save_messages(args.file, system_prompt, messages, response, temp, model, config)
        logger.info("Script execution completed successfully")
    except Exception as e:
        logger.exception("An error occurred during script execution")

if __name__ == "__main__":
    main()
