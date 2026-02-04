# Bug Process

The process for bugs is as follows:

- Users place bugs in markdown files in the ./doc/bugs/new directory. Include as much information as you can, and ensure that the bug actually exists in the code you're making the PR to, please!
- The Agent then triages the bugs. For bugs that can be directly solved, a single bug should be solved and the file moved to ./doc/bugs/fixed - for bugs that require more information (logs, etc) the questions should be added to the bug file, and the bugs moved to "current".
- If the bugs cannot be replicated, or the report is otherwise questionable, the Agent may ask the manager to move them to ./doc/bug/rejected
- Agent MUST add notes about the bug's cause, potential solutions, and actual final solution (if any) to the bug file.
