
Dev env set up with pyenv
==========================


* create a venv using pyenv

	[dsun@tdclpf9ivd006 aicodeagent]$ pyenv virtualenv 3.12.11 denis_venv

	* activate a venv

	[dsun@tdclpf9ivd006 aicodeagent]$ pyenv activate  denis_venv


	* list current venvs

	(denis_venv) [dsun@tdclpf9ivd006 aicodeagent]$ pyenv virtualenvs
	  3.12.11/envs/denis_venv (created from /tools/.pyenv/versions/3.12.11)
	  3.12.11/envs/venv (created from /tools/.pyenv/versions/3.12.11)
	* denis_venv (created from /tools/.pyenv/versions/3.12.11)
	  venv (created from /tools/.pyenv/versions/3.12.11)



	(denis_venv) [dsun@tdclpf9ivd006 aicodeagent]$ pyenv virtualenv-delete venv
	pyenv-virtualenv: remove /tools/.pyenv/versions/3.12.11/envs/venv? (y/N) y
	(denis_venv) [dsun@tdclpf9ivd006 aicodeagent]$ pyenv virtualenvs
	  3.12.11/envs/denis_venv (created from /tools/.pyenv/versions/3.12.11)
	* denis_venv (created from /tools/.pyenv/versions/3.12.11)


	* display full path of python

	(denis_venv) [dsun@tdclpf9ivd006 aicodeagent]$ pyenv which python
	/tools/.pyenv/versions/denis_venv/bin/python

	if not using pyenv

	(denis_venv) [dsun@tdclpf9ivd006 aicodeagent]$ which python
	/tools/.pyenv/shims/python












////////////////////////////////////////////
OTHER STUFF
///////////////////////////////////////////////





boot dev leasson: build an AI agent
====================================

	https://www.youtube.com/watch?v=YtHdaXuOAks

	https://www.boot.dev/lessons/b22c58d0-7806-4b70-9dd0-0f5bed625471

	build the functionality for our Agent to run arbitrary Python code.


	FunctionDeclaration 
	-------------------

	A FunctionDeclaration in the context of Google AI, particularly within platforms like Vertex AI and the Gemini API, 
	represents a structured definition of a function that can be used as a "tool" by a large language model (LLM). 
	This declaration informs the model about the existence and capabilities of a specific function, 
	allowing the model to decide when and how to call it to fulfill a user's request.

	FunctionDeclaration acts as a contract between the LLM and the external functions it can leverage, enabling the 
        model to extend its capabilities beyond pure text generation.



Testing  "CH3: Function Calling - 3: Function Calling"
======================================================

	Run the CLI commands to test your solution.

	python  main.py "run tests.py" --verbose

	Expecting exit code: 0
	Expecting stdout to contain all of:
	Ran 9 tests

	### python run main.py "get the contents of lorem.txt" --verbose

	Expecting exit code: 0
	Expecting stdout to contain all of:
	wait, this isn't lorem ipsum


	### python main.py "create a new README.md file with the contents '# calculator'" --verbose

	Expecting exit code: 0

	### python  main.py "what files are in the root?" --verbose

	Expecting exit code: 0
	Expecting stdout to contain all of:
	lorem.txt
	README.md




Agents
=====

So we've got some function calling working, but it's not fair to call our program an "agent" yet for one simple reason:

It has no feedback loop.

A key part of an "Agent", as defined by AI-influencer-hype-bros, is that it can continuously use its tools to iterate on its own results. 

So we're going to build two things:


A loop that will call the LLM over and over

A list of messages in the "conversation". It will look something like this:


User: "Please fix the bug in the calculator"
Model: "I want to call get_files_info..."
Tool: "Here's the result of get_files_info..."
Model: "I want to call get_file_content..."
Tool: "Here's the result of get_file_content..."
Model: "I want to call run_python_file..."
Tool: "Here's the result of run_python_file..."
Model: "I want to call write_file..."
Tool: "Here's the result of write_file..."
Model: "I want to call run_python_file..."
Tool: "Here's the result of run_python_file..."
Model: "I fixed the bug and then ran the calculator to ensure it's working."






Update Code
============

Let's test our agent's ability to actually fix a bug all on its own.

Assignment

Manually update calculator/pkg/calculator.py and change the precedence of the + operator to 3.

Run the calculator app, to make sure it's now producing incorrect results: uv run calculator/main.py "3 + 7 * 2" 
(this should be 17, but because we broke it, it says 20)

Run your agent, and ask it to "fix the bug: 3 + 7 * 2 shouldn't be 20"























