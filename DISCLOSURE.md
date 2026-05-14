# Disclosure for XLSX

## AI Usage

This project is an example of my selective use of LLMs to build small, well-defined, and useful libraries and tools _that I understand as if I wrote them myself_.

### Level 5

The "[Using AI to Contribute to Open Source](https://www.visidata.org/blog/2026/ai/)" article provides an excellent framework for identifying how AI is used.

This is _by design_ a **[Level 5](https://www.visidata.org/blog/2026/ai/#level-5%3A-bots-coded%2C-human-understands-completely)** project, quoted below.

> **Level 5: Bots coded, human understands completely**
>
> At level 5, bots generated the majority of the code, but a human was still involved at every step of the way, like an individual contributor. Every line of code has been reviewed with the human's full attention.
> The human has examined it and validated it logically--or at least has done what a human can do in that regard. They understand the algorithm and how it works.

### Approach

I worked with Claude's Sonnet 4.6 (Adaptive) via the web UI using a free plan to develop this shard. It was an iterative process. I started with a motivation + planning prompt and then worked through the design until it was ready to start implementing.

Here's the opening prompt we started from:

> I would like to implement a Crystal shard / library for reading and writing Excel XLSX documents. I want to be able to do the following when using this library:
>
> 1. Read and write the same content that I would with a CSV file.
> 2. Define an API model that looks and feels like the CSV module in Crystal's standard library: https://crystal-lang.org/api/1.20.0/CSV.html
> 3. Open an existing XLSX document and use it as a template to write more data into.
> 4. Manage worksheets so that I can in turn select and use individual worksheets when reading and writing data.
> I have no interest in using the API to create or consume charts, macros, pivots or any features of Excel beyond the ability to read and write contents of worksheets. Before starting to write any code, please explain to me (briefly) how the format works, and then propose an API. Let me decide when it's time to begin an implementation.

Through the design discussion, I was opinionated about what I wanted the API to feel like, while I also didn't know how XLSX files (ZIPs of XML, hurrah!) were structured.

We didn't start implementing a single file until we were clear about the following:

- Usage pattern for the API, both to make fresh XLSX document and to be able to use a template.
- File / folder structure, keeping internals isolated, and well separated from the main components
- Testing (using `spectator`) from the beginning, which Claude had to learn about

It took several days and many stops and starts because I'm using the free plan and ran out of my "free messages" often. In hindsight this turned out to be a good thing.

While I was already keeping up with the generated code and making sure I understood it because of the (you might call it pedantic) pace at which we were working, the waiting time between usage credits (usually five hours from when I run out) gave me time to think about
- progress so far,
- what I wanted to do next, and
- if I wanted to revisit or change anything.

At least three times I came back from the break with a request to refactor a recent implementation or revisit a design decision. I honestly believe I wouldn't have made these changes without _my own thinking time_.

In hindsight, I always had breaks between working sessions, some during the work day and some when I stopped to go home and spend time with my family. I've noticed the same benefits working that way, and it makes sense to me that I should actively incorporate _waiting and thinking time_ into all my future use of AI tools.
