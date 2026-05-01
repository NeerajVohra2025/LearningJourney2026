import os

# Environment configuration management
from dotenv import load_dotenv

# Load environment variables for secure API key management and model configuration
load_dotenv()

# llm client
from langgraph_learning.util.llm_client import llm_google, llm_ollama, llm_groq

# Using Google Gemini for excellent tool calling support
# Note: Ollama's smaller models have limited tool-calling capabilities
llm = llm_google

# typing
from typing import TypedDict, List, Annotated, Optional, Literal


# LangGraph Components
from langgraph.graph import StateGraph, START, END, add_messages
from langgraph.prebuilt import ToolNode

# tools_condition
# Like a traffic cop that reads the LLM’s response and says:
# “Go to the tools lane” or “Go to the final answer lane”.
from langgraph.prebuilt import tools_condition

# langgraph.checkpoint = module for checkpointing (saving state).
# memory = a specific implementation that stores checkpoints in memory (RAM).
# MemorySaver = a class that saves and restores graph state in memory.

# MemorySaver
# Like a RAM-based autosave system:
# “Whenever something important happens in the workflow, I’ll save a snapshot in memory so we can resume later.”


from langgraph.checkpoint.memory import MemorySaver

# LangChain core components for agentic AI implementation
from langchain_core.messages import (
    HumanMessage,
    AIMessage,
    ToolMessage,
    AnyMessage,
    SystemMessage,
)
from langchain_core.tools import tool

# Import graph visualization utility
from langgraph_learning.util.graph_utils import GraphVisualizer

# External API integrations for multi-tool capabilities
# We configure three specialized tools, each optimized for specific research needs:
# 1. Arxiv: Academic papers and scholarly research
# 2. Wikipedia: General knowledge and encyclopedic content
# 3. Tavily: Real-time web search for current events
# 4. Math: Simple mathematical calculations
# 5. Email: Send emails (sensitive)
from langgraph_learning.util.langgraph_llm_tool import (
    arxiv_tool,
    wikipedia_tool,
    tavily_tool,
    calculate_math,
    send_email,
)


# Agent State - Common state structure for the workflow
class AgentState(TypedDict):
    """State schema for the multi-agent system."""

    messages: Annotated[list[AnyMessage], add_messages]  # Conversation history
    next_agent: Optional[str]  # Which agent should process next (for routing)
    user_question: str  # User's original question


# --- TOOL CONFIGURATI  ON ---

SAFE_TOOLS = [arxiv_tool, wikipedia_tool, tavily_tool, calculate_math]
SENSITIVE_TOOLS = [send_email]

# Bind ALL tools to LLM - this allows the LLM to intelligently choose which tools to call
ALL_TOOLS = SAFE_TOOLS + SENSITIVE_TOOLS
llm_with_tools = llm.bind_tools(ALL_TOOLS)
print(f"type of llm_with_tools: {type(llm_with_tools)}")
print(f"llm_with_tools: {llm_with_tools}")

# Define names for checking
SENSITIVE_TOOL_NAMES = {t.name for t in SENSITIVE_TOOLS}


# --- NODE DEFINITIONS ---
safe_tools_node = ToolNode(SAFE_TOOLS)
sensitive_tools_node = ToolNode(SENSITIVE_TOOLS)


def chat_node(state: AgentState) -> AgentState:
    """
    Intelligent Chat Node
    The agent will:
    1. Receive user query
    2. Decide whether to answer directly or call a tool.
    3. If tool is called then call the tool.
    4. Synthesize results into formatted responses
    """
    messages = state["messages"]
    system_prompt = """You are an intelligent research assistant with access to specialized tools.

## Your Capabilities

You have access to the following tools:
- **arxiv_tool**: Search academic papers and scholarly research (best for: physics, math, CS, STEM)
- **wikipedia_tool**: Search encyclopedia for general knowledge, history, established facts
- **tavily_tool**: Search current web content for latest news and real-time information
- **calculate_math**: Perform mathematical calculations safely
- **send_email**: Send emails (SENSITIVE - requires user approval)

## Response Formatting Guidelines

When presenting information to users, ALWAYS follow these formatting rules:

1. **Use bullet points (•)** for main ideas and findings
2. **Highlight KEY INSIGHTS** in bold using **text** format
3. **Be concise but comprehensive** - quality over quantity
4. **Focus on actionable information** - what the user can do with this knowledge
5. **Use clear, professional language** - avoid jargon unless necessary

## Example Response Format

When you gather information from tools, present it like this:

• Main finding or fact
• Supporting detail or context
• **KEY INSIGHT**: Critical discovery or important point
• Additional relevant information
• **RECOMMENDATION**: Suggested action or next step

## Tool Usage Strategy

- Use **wikipedia_tool** for historical facts and general knowledge
- Use **arxiv_tool** for academic research and scientific papers
- Use **tavily_tool** for current events, news, and time-sensitive information
- Use **calculate_math** for any mathematical calculations
- Always ask for confirmation before using **send_email**

## Important

- After gathering information with tools, synthesize and summarize the findings
- Don't just dump raw tool output - analyze and present it clearly
- If multiple tools are needed, use them in sequence and combine results
- Always cite which tool provided which information
"""
    messages_with_system = [SystemMessage(content=system_prompt)] + messages
    response = llm_with_tools.invoke(messages_with_system)
    return {
        "messages": [response],
        "next_agent": "research_agent",
        "user_question": state["user_question"],
    }


# --- SMART ROUTING ---
def smart_tools_condition(
    state: AgentState,
) -> Literal["safe_tools", "sensitive_tools", "__end__"]:
    """
    Custom routing logic that mimics `tools_condition` but splits traffic.
    """
    messages = state["messages"]
    last_msg = messages[-1]

    # No tool calls? End.
    if not isinstance(last_msg, AIMessage) or not last_msg.tool_calls:
        return "__end__"

    # Check first tool call
    tool_call = last_msg.tool_calls[0]
    tool_name = tool_call["name"]

    if tool_name in SENSITIVE_TOOL_NAMES:
        return "sensitive_tools"
    else:
        return "safe_tools"


def generate_graph() -> StateGraph:
    """
    Generate the state graph for the multi-agent system.
    """
    graph = StateGraph(AgentState)

    # 1. Add Nodes
    graph.add_node("chat", chat_node)
    graph.add_node("safe_tools", safe_tools_node)
    graph.add_node("sensitive_tools", sensitive_tools_node)

    # 2. Add Edges
    graph.add_edge(START, "chat")

    # 3. Conditional Edge using custom smart_tools_condition
    graph.add_conditional_edges(
        "chat",
        smart_tools_condition,
        {
            "safe_tools": "safe_tools",
            "sensitive_tools": "sensitive_tools",
            "__end__": END,
        },
    )

    # 4. Loop back
    graph.add_edge("safe_tools", "chat")
    graph.add_edge("sensitive_tools", "chat")

    # 5. Compile with Interrupt
    memory = MemorySaver()

    # We interrupt before the sensitive_tools node ONLY.
    compiled_graph = graph.compile(
        checkpointer=memory, interrupt_before=["sensitive_tools"]
    )

    return compiled_graph


def draw_graph(compiled_graph) -> None:
    try:
        GraphVisualizer.save_graph(compiled_graph, "smart_routing.png")
        print("Graph saved to: smart_routing.png")
    except Exception as e:
        print(f"Could not draw graph: {e}")


# --- MAIN EXECUTION LOOP ---


def main():
    compiled_graph = generate_graph()
    draw_graph(compiled_graph)
    config = {"configurable": {"thread_id": "my_smart_chatbot"}}

    print("🤖 Hi! I'm your smart assistant.")
    print("I can help with research, summaries, emails, and more.")
    print(
        "⚠️  Don’t worry—I’ll always ask your permission before doing anything sensitive (like sending emails)."
    )
    print("Type 'bye', 'exit', or 'quit' anytime to end the chat.\n")

    while True:
        try:
            user_input = input("💬 You: ").strip()

            # Handle empty input
            if not user_input:
                print("Hmm, you didn’t type anything. Try again!")
                continue

            # Handle exit conditions
            if user_input.lower() in ["quit", "exit", "bye"]:
                print("Goodbye! Have a great day! 😊")
                break

            # Initialize state
            initial_state = {
                "messages": [HumanMessage(content=user_input)],
                "user_question": user_input,
            }

            # 1. Stream the AI's thinking and actions in real time
            print("\n🧠 Thinking...\n")
            for event in compiled_graph.stream(
                initial_state, config, stream_mode="updates"
            ):
                for node, output in event.items():
                    print(f"--- Node: {node} finished ---")
                    if "messages" in output:
                        for msg in output["messages"]:
                            if isinstance(msg, AIMessage) and msg.tool_calls:
                                for tool_call in msg.tool_calls:
                                    print(
                                        f"🛠️  Planning to use: **{tool_call['name']}**"
                                    )
                                    args = tool_call["args"]
                                    print(f"   Details: {args}")
                            elif isinstance(msg, ToolMessage):
                                print(
                                    f"🔧 Tool Output [{msg.name}]: {msg.content[:200]}..."
                                )
                            elif isinstance(msg, AIMessage) and msg.content:
                                print(f"💬 Assistant: {msg.content}")

            # Check if the workflow is paused before a sensitive action
            snapshot = compiled_graph.get_state(config)
            if snapshot.next and "sensitive_tools" in snapshot.next:
                print("\n🛑 **Action Requires Your Approval**")
                last_msg = snapshot.values["messages"][-1]
                call = last_msg.tool_calls[0]
                tool_name = call["name"]

                print(f"\n📋 The assistant wants to run: **{tool_name}**")
                args = call["args"]
                if tool_name == "send_email":
                    print(f"📧 To: {args.get('recipient', '—')}")
                    print(f"📌 Subject: {args.get('subject', '—')}")
                    body_preview = (
                        (args.get("body", "")[:100] + "...")
                        if len(args.get("body", "")) > 100
                        else args.get("body", "")
                    )
                    print(f"📄 Body preview: {body_preview}")
                else:
                    print(f"⚙️  Arguments: {args}")

                # Safe input loop for approval
                while True:
                    decision = (
                        input("\n✅ Approve this action? (y/n): ").strip().lower()
                    )
                    if decision in ("y", "yes"):
                        print("\n🚀 Approved! Proceeding...\n")
                        # Resume execution
                        for event in compiled_graph.stream(
                            None, config, stream_mode="updates"
                        ):
                            for node_name, node_output in event.items():
                                if "messages" in node_output:
                                    for msg in node_output["messages"]:
                                        if isinstance(msg, ToolMessage):
                                            content = msg.content
                                            display = (
                                                (content[:200] + "...")
                                                if len(content) > 200
                                                else content
                                            )
                                            print(
                                                f"✅ Result from **{msg.name}**: {display}"
                                            )
                                        elif isinstance(msg, AIMessage) and msg.content:
                                            print(f"💬 Assistant: {msg.content}")
                        print()  # Final spacing
                        break
                    elif decision in ("n", "no"):
                        print("\n❌ Action canceled by you.")
                        # Inject a rejection message as if the tool returned an error
                        rej_msg = ToolMessage(
                            tool_call_id=call["id"],
                            content="User rejected this action.",
                            name=call["name"],
                        )
                        compiled_graph.update_state(
                            config, {"messages": [rej_msg]}, as_node="sensitive_tools"
                        )
                        print("🔄 Letting the assistant know...\n")
             
             # Let the AI respond to the rejection
                        for event in compiled_graph.stream(
                            None, config, stream_mode="updates"
                        ):
                            for node_name, node_output in event.items():
                                if "messages" in node_output:
                                    for msg in node_output["messages"]:
                                        if isinstance(msg, AIMessage) and msg.content:
                                            print(f"💬 Assistant: {msg.content}")
                        print()
                        break
                    else:
                        print("❓ Please type 'y' for yes or 'n' for no.")

        except KeyboardInterrupt:
            print("\n\n👋 Got it—ending chat. See you next time!")
            break
        except Exception as e:
            print(f"\n⚠️  Something unexpected happened: {e}")
            print("But don’t worry—I’m still here! Try again.\n")
