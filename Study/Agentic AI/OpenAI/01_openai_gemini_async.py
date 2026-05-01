# configurations
import os
# openai classes
from agents import Agent,Runner,AsyncOpenAI,OpenAIChatCompletionsModel
from agents.run import RunConfig
#
import asyncio  # using it can call asynchronous function.
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
# print(provider.api_key)
# print(provider.base_url)

# step#2 provider's model
model=OpenAIChatCompletionsModel(
    model="gemini-2.0-flash",
    openai_client=provider
)

# step#3 config (optional) available at Run, Agent and Global Labels
config=RunConfig(
    model=model,
    model_provider=provider,
    tracing_disabled=True,  # default false for open AI
    )

# Agent
async def main():
    # step#4 create agent (optional) available at Run, Agent and Global Labels
    agent=Agent(name='Assistant',instructions='You are a helpful assistant',model=model)
    # Runner is reponsible for (agent's orchestrator) run is async
    # step#5 run the agent with Runner.run() method
    # The await keyword can only be used inside an asynchronous function.
    result=await Runner.run(agent,"Tell me about Open AI Agentic SDK",run_config=config)
    print("\nCALLING OPEN AI AGENT\n")
    print(result.final_output)
asyncio.run(main())
