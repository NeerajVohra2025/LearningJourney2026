# import chainlit as cl
import chainlit as cl
# openai classes
from agents import Agent,Runner,AsyncOpenAI,OpenAIChatCompletionsModel
from agents.run import RunConfig
# configurations
import os
import asyncio # for async function calls
# asyncio.run(main())

# Load .env file
from dotenv import load_dotenv
load_dotenv()
# Read variables
gemini_api_key = os.getenv("GOOGLE_API_KEY")
#print(gemini_api_key)

# step#1 define external_client/provider
provider=AsyncOpenAI(
    api_key=os.getenv("GOOGLE_API_KEY"),
    base_url="https://generativelanguage.googleapis.com/v1beta/openai"
)
# step#2 provider's model
model=OpenAIChatCompletionsModel(
    model="gemini-2.0-flash",
    openai_client=provider
)

# step#3 config at run time
config=RunConfig(
    model=model,
    model_provider=provider,
    tracing_disabled=True,  # default false for open AI
    )
# step#4 create open-AI agent 
agent=Agent(name='Assistant',instructions='You are a helpful assistant',model=model) 


# step#5 chainlit integration

@cl.on_chat_start
async def start():
    await cl.Message(
        content="Hello! I'm your AI assistant. How can I help you today?"
    ).send()

@cl.on_message
async def main(message: cl.Message):   # asynchronous message add async and return replace with await
    # our custom logic goes here
    result= await Runner.run(
    starting_agent=agent,
    input=message.content,
    run_config=config)
    # send a response back to the user
    await cl.Message(
            content=result.final_output).send()
