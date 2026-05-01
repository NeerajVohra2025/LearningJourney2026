import chainlit as cl

@cl.on_chat_start
async def start():
    await cl.Message(
        content="Hello! I'm your AI assistant. How can I help you today?"
    ).send()
	
@cl.on_message
async def main(message: cl.Message):   # asynchronous message add async and return replace with await
    # our custom logic goes here
    # send a fake response back to the user
    await cl.Message(
            content=f"Received: {message.content} " 
        ).send()