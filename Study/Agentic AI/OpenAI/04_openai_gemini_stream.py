# openai classes
from agents import Agent,Runner,AsyncOpenAI,OpenAIChatCompletionsModel,set_default_openai_api,set_default_openai_client,set_tracing_disabled
from agents.run import RunConfig
from openai.types.responses import ResponseTextDeltaEvent
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
    model="gemini-2.5-pro-exp-03-25",
    openai_client=provider
)
# streaming configurations
set_default_openai_client(client=provider, use_for_tracing=False)
set_default_openai_api("chat_completions")
set_tracing_disabled(disabled=True)

# step#3 config at run time
config=RunConfig(
    model=model,
    model_provider=provider,
    tracing_disabled=True,  # default false for open AI
    )
# step#4 create open-AI agent 
async def main():
    agent = Agent(
        name="Joker",
        instructions="You are a helpful assistant.",
        model=model
    )

    result = Runner.run_streamed(agent, input="Please tell me 5 jokes.")
    async for event in result.stream_events():
        if event.type == "raw_response_event" and isinstance(event.data, ResponseTextDeltaEvent):
            print(event.data.delta, end="", flush=True)



asyncio.run(main())