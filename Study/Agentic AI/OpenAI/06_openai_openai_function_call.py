# openai classes
from agents import Agent,Runner,ItemHelpers,function_tool
from openai.types.responses import ResponseTextDeltaEvent 
# configurations
import os
import asyncio # for async function calls
# asyncio.run(main())
import random # for random number generation


# Load .env file
from dotenv import load_dotenv
load_dotenv()

# Read variables
openai_api_key = os.getenv("OPENAI_API_KEY")
print(openai_api_key)

@function_tool
def how_many_jokes() -> int:
    return random.randint(1,3) # function to return random number of jokes

async def main():
    # Create an agent instance
    agent = Agent(
        name="OpenAI Stream Agent",
        instructions="First call the `how_many_jokes` tool, then tell that many jokes..",
        tools=[how_many_jokes], # list of tools to be used by the agent
    )
# When we assign task to the agent,asynchronous function is called
    # The agent will respond to the task in a streaming manner  
    #wil call the function in the agent class
    # will interact with other agents
    # will create a file with the response
    result=Runner.run_streamed(
        starting_agent=agent,
        input="Hello, can you tell me some jokes?",
    )
    print("Agent is running...")
    async for event in result.stream_events():
        # We'll ignore the raw responses event deltas
        if event.type == "raw_response_event":
            continue
        elif event.type == "agent_updated_stream_event":
            print(f"Agent updated: {event.new_agent.name}")
            continue
        elif event.type == "run_item_stream_event":
            if event.item.type == "tool_call_item":
                print("-- Tool was called")
            elif event.item.type == "tool_call_output_item":
                print(f"-- Tool output: {event.item.output}")
            elif event.item.type == "message_output_item":
                print(f"-- Message output:\n {ItemHelpers.text_message_output(event.item)}")
            else:
                pass  # Ignore other event types 
try:
    asyncio.run(main())
except:
    pass
print("=== Agent Run complete ===")
