# The nuts and bolts of agent-based modelling for archaeological science

## Abstract: 
Agent-based models (ABMs) are slowly becoming a common part of the archaeological science toolbox. However, even as they become more common there remains a lack of understanding among most archaeologists of what they are, how they work, and how they can contribute to broader archaeological research programs. Over the last few decades, articles and conference sessions applying agent-based models have demonstrated their utility to a variety of topics; however to the uninitiated agent-based models remain black boxes that are difficult to evaluate or to apply to non-ABM research. In this forum, we will attempt to dispel the mystery of archaeological agent-based models without delving too far into jargon filled computer code. Rather, we will present interactive and live-running agent-based models to show how archaeologists design and use them to address typical archaeological research questions. Presenters will highlight specific problems they encountered during their design, coding, parameterising, or validation phases and the choices they made to find a solution. The agent-based models presented will be available for forum participants to download and run themselves so they can follow along with the demonstrations and discuss their application.

## Discussants: 
Sean Bergin; James Allison; Claudine Gravel-Miguel; Jonathan Reeves; Grant Snitker; Nicolas Gauthier; Stefani Crabtree; C. Michael Barton

## Presentation Guidelines: 
(Inspired by Ben Marwick’s R forum at a previous SAA meeting, e.g. https://github.com/benmarwick/SAA2017-How-to-do-archaeological-science-using-R)

As the abstract above states, the idea of this panel is to have live-running ABMs combined with brief discussions of aspects of the code to help dispel their mystery for non-modellers and/or newbie-modellers. Ideally, this will introduce attendees to what is possible and how simple it can (sometimes) be. I had in mind that code would be altered on the fly to illustrate how slightly different lines of code can have large implications for the running of the model. This is a bold proposition I realize, but for example, I envision having two versions of a given line with a commenting character that can be quickly erased from one and put on the other. For example, you could switch between a random walk and directed movement. Alternatively, you could go the cooking show route, where the analysed results from the second version of the code are hiding pre-cooked in the oven (so to speak). We don’t need a detailed play by play of the entire model code, just focus on one or two aspects.
*	You should prepare your demonstration so that it takes about 10 minutes, including addressing simple questions from the audience. This should also leave a few minutes for a more detailed question after.
  *	I expect questions will largely be of the can-you-make-the-model-do-X type. If so, try to address them in terms of how you’d go about changing the code, or additional data for parameterization, etc.
*	Your presentation should (ideally) use an ABM that you developed as part of a specific research project rather than a tutorial model to illustrate some coding skills. We want to highlight the research question and how the ABM helps to address that question, and not to get bogged down explaining while vs for loops.
*	You are welcome to use whatever coding platform you like. However, because I’d like to share the code with attendees in advance (all together in this GitHub repo), please make it will work on a vanilla version of the platform without extra DLLs, custom or non-base add-ons, or modified config files.
* The idea is to entice others to join our ABM team. Make your demo approachable and optimistic rather than focusing on the dreary slog of that time you spent three weeks getting a single line of code to work right ;)

## Structuring your demo
*	Ideally, do not use slides at all.
*	Begin with the research question and a brief explanation of what ABM adds to the usual ways to address the question. 
*	Outline the broad framework of the model and what, if any, data you are using to parameterize the model.
*	Describe in more detail how a specific section of the code works to create some result. Flip between the code and the output (I’m picturing NetLogo tabs here) to explain how the code produces the output.
*	Describe what change you need to make and why, then describe how the second version of the code line(s) do something different. 
*	Show the result and describe what to look for to notice the changes to agent behaviour or other outputs.
*	If your ABM typically takes a long time to run, think about a way to speed it up or simplify it for the purposes of the demo. Perhaps by reducing the size of the landscape or agent population, reducing the number of outputs, or decreasing the number of things happening per time step. 
*	Finish by returning to the research question to show how the different versions of the code answer the question differently, or make different assumptions, etc.

## Code style requirements
*	Comment your code extensively in as simple language as possible, or at least the portion of it that you are specifically focusing on for the demo. Include comments to break the code up into sections, as well as specific comments for individual lines.
*	Use custom function names and variable names that are highly readable. The goal is to make it as clear as possible what the code is actually doing and where.
*	Package your code with a README file that includes explicit instructions about how to download the modelling platform and what version you’re using, etc. Everything a complete novice would need. Don’t assume they know how to compile code or what an IDE is. Also include any required data files, such as initializing variable values or maps. If you are unable/unwilling to share data, invent some fictional data for the purposes of the demo.
