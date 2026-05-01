# openai classes
from agents import Agent,Runner
from openai.types.responses import ResponseTextDeltaEvent 
# configurations
import os
import asyncio # for async function calls
# asyncio.run(main())

# Load .env file
from dotenv import load_dotenv
load_dotenv()

# Read variables
openai_api_key = os.getenv("OPENAI_API_KEY")
print(openai_api_key)

async def main():
    # Create an agent instance
    agent = Agent(
        name="OpenAI Stream Agent",
        instructions="You are a helpful assistant."
        
    )
# When we assign task to the agent,asynchronous function is called
    # The agent will respond to the task in a streaming manner  
    #wil call the function in the agent class
    # will interact with other agents
    # will create a file with the response
    result=Runner.run_streamed(
        starting_agent=agent,
        input="Tell me the 2 jokes?",
    )
    async for event in result.stream_events(): # With in the event loop, we can call the function in the agent class
        if event.type == "raw_response_event" and isinstance(event.data, ResponseTextDeltaEvent):
            print(event.data.delta,end="",flush=True) # print the response in a streaming manner, without new line and flush the output buffer
        
asyncio.run(main())

