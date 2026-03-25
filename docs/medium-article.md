# You're Paying for Claude Max. But Are You Actually Using It?

I pay for Claude Max. It's not cheap. And for a while, I had this uncomfortable feeling that I wasn't getting my money's worth. Not because the AI wasn't good, but because of how I was using it.

Here's what kept happening: I'd give Claude Code a task, something meaty like "refactor this module" or "add integration tests for the auth layer." It would start working. I'd tab away to do something else. Check Slack. Review a PR. Grab coffee. Ten minutes later, I'd switch back and see it: *"Waiting for your input."*

It had been sitting there. Idle. For ten minutes. Burning through my subscription window while I was oblivious.

The worst part wasn't the wasted time. It was the math. I'm paying a monthly subscription for a tool that can crank through serious engineering work, and I'm leaving it parked because I didn't know it was done. Every minute Claude Code sits waiting for my approval is a minute I'm not getting value from what I paid for.

So I'd start panic-checking. Tab to the terminal. Not done yet. Tab back. Two minutes later, tab again. Still running. Tab back. Eventually I'd miss the actual moment it needed me, and the cycle would repeat. It felt like I was babysitting my AI assistant instead of the other way around.

If you're paying for Claude Max, Codex, or any AI coding subscription, you've probably felt this too. That nagging question: *am I actually using this thing to its full potential?*

---

## The Real Problem

The problem wasn't Claude Code. It was me. Or more specifically, the gap between when the AI finishes and when I notice.

Think about it: these AI coding assistants are fast. They can refactor a module in 30 seconds. Write a test suite in a minute. But if I don't come back for 10 minutes, that speed is meaningless. The bottleneck isn't the AI. It's my attention.

I needed a way to close that gap. Something that would tell me the moment Claude Code was done, or the moment it needed me to make a decision, so I could keep it working continuously. Maximize the tokens I'm paying for.

---

## Building the Fix

The idea was stupid-simple: *what if my terminal just told me?*

A desktop notification when a command finishes. That's it. I started with a small bash script. Wrap a command, catch the exit code, fire a notification. I called it `cli-alert`. It worked. For about a week, it was exactly what I needed.

Then I left my desk during a long deploy. Came back to a macOS notification in my notification center, timestamped twenty minutes ago.

So I added webhooks. I set up a private Slack channel, just me in it, and had the tool post there when something finished. Now my phone would buzz. That changed everything. A build finishes while I'm making lunch? Slack ping. Claude Code needs approval? I see it before I sit down.

But here's where it got interesting. Once I had Slack notifications on my phone, I realized I could pair it with Chrome Remote Desktop. Now when Claude Code finishes or needs my input, I get the Slack notification on my phone, open Chrome Remote Desktop, review and approve right from my phone, and Claude Code keeps working. No downtime. No wasted tokens. I can be at a coffee shop, on the couch, wherever. The AI never sits idle waiting for me.

That's when the subscription started paying for itself.

---

## Why Pure Bash?

People ask me this. Why not Python? Why not Go?

It started as convenience, I was already in the terminal. But the constraint became a feature. Zero dependencies means zero setup friction. No `npm install`. No runtime to manage. You install it, source it, and it works. On macOS, Linux, WSL, any machine with bash.

Building production-grade software in bash is a different kind of challenge though. No package ecosystem. No standard library for HTTP or JSON. You build everything from scratch.

The main script ended up at 3,196 lines with over 450 tests. I know "tested bash code" sounds like an oxymoron, but if you're shipping something that modifies shell configs and fires HTTP requests to external services, you'd better have tests catching regressions before your users do.

---

## From cli-alert to shelldone

The original tool worked, but it was built for people like me, developers comfortable editing config files. I wanted something anyone could use.

So I rebuilt the experience. The setup is now a guided wizard that walks you through everything: notification channels, sound preferences, AI tool integrations. It auto-detects what you have installed and suggests sensible defaults. The whole thing is a TUI, a terminal user interface, built in pure bash. No ncurses. No framework. Just ANSI escape codes, cursor positioning, and a lot of testing across terminal emulators.

The rebrand happened naturally. "cli-alert" described what it did. "shelldone" described what it meant: your shell is done, and it's telling you about it.

---

## The AI Hook That Changed Everything

The real unlock was hooking into AI coding assistants natively.

Claude Code has a hook system. When it finishes a task or needs your input, it fires a shell command. shelldone registers itself as that hook. So when Claude Code stops and says "I need you to review this," shelldone catches it instantly, desktop notification and Slack message, whatever you've configured. You review, approve, and the AI keeps going. No dead time.

I added the same for Gemini CLI, Codex, Copilot, and Cursor. Each has its own hook format, some use JSON, one uses TOML, another uses separate files per hook.

Here's something I discovered the hard way: not every AI CLI supports a "waiting for input" hook. Claude Code does. Gemini CLI mostly does. But Codex, Copilot, and Cursor only fire hooks when the task is *complete*, not when they're waiting for you. I documented this honestly rather than pretending it worked.

---

## What I Learned Building in the Open

**Testing bash is worth the effort.** My test suite catches things I'd never notice manually, a config not parsing on Linux, a webhook payload missing a field. Every feature gets tests before it ships.

**TUI in bash is underrated.** I built a full interactive wizard with progress indicators, color-coded badges, spinners, and smart prompts, all in bash. It's not React, but it works in every terminal on every OS without installing anything.

**Zero dependencies is a feature, not a limitation.** Packaging for Homebrew, APT, and Scoop taught me how much easier distribution is when there's nothing to bundle.

**Open source forces you to care about the edges.** When it was just for me, "works on my Mac" was enough. Once others could install it, I had to think about Linux notification daemons, WSL interop, and terminals that don't support 256 colors.

---

## The Payoff

Here's my workflow now: I give Claude Code a task. I walk away. I get a Slack notification on my phone when it's done or needs me. I open Chrome Remote Desktop, review, approve, give it the next task. Walk away again. Repeat.

No panic-checking. No wasted idle time. No "I wish I'd seen this ten minutes ago."

My private Slack channel has become a personal command center. Every build, every AI task, every deploy, they all report there. I glance at my phone and know exactly what's waiting.

I went from feeling like I was wasting my Claude Max subscription to feeling like I'm squeezing every token out of it. The AI works. I get notified. I respond. It keeps working. The loop is tight now.

All because I got tired of checking if Claude Code was done yet.

---

**shelldone is open source, MIT licensed, and built in pure bash with zero dependencies.**

If you're paying for an AI coding subscription and feel like you're not getting your money's worth, give it a try.

GitHub: [github.com/nareshnavinash/shelldone](https://github.com/nareshnavinash/shelldone)
Website: [nareshnavinash.github.io/shelldone](https://nareshnavinash.github.io/shelldone)

Contributions and feedback are always welcome. The codebase is pure bash, so it's approachable even if you've never contributed to open source before. Pull requests are always welcome.
