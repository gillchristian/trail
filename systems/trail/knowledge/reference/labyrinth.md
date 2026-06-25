Notes on the synthesis of labyrinths
Alvaro Videla
Solving problems in software development is not unlike finding your way out of a maze. Consider how documentation might reflect the twists and turns you faced along way—not just the end result.

No one realized that the book and the labyrinth were one and the same.—Jorge Luis Borges

One morning you arrive at the office to find your manager waiting for you with a new task: She wants you to choose a JavaScript framework for the company. All new projects will be built using the library of your choice. What a responsibility!

A quick internet search reveals a plethora of frameworks to choose from. You land on a website that compares their pros and cons. From there, you decide to further explore the two most popular ones: Let’s call them reaction.js and view.js.


As soon as you dive into reaction.js, you notice that you need to learn its XML markup language. Soon, your browser has five open tabs just for this framework, and you’re switching back and forth between “How to Get Started with reaction.js,” its XML markup reference, and a Stack Overflow question on how to display data in a template. Moving from browser tab to browser tab makes you feel like you’re lost inside a labyrinth. After an hour of playing with reaction.js you decide to test view.js—and a whole new section of the labyrinth opens up as you follow documentation links, search for answers, and try some code in your terminal.

After a while you reach the center of the labyrinth, where you find the Minotaur. Its name is reaction.js. It’s time to share the news—your decision about the best framework for your purposes—with the rest of the company. But some of your coworkers seem skeptical. After all of your hard work learning that XML-like markup language and your struggle to get all of the dependencies working, they don’t seem to understand why they should use reaction.js. You defeated the Minotaur, but no one understands why or how—so nobody believes you.

The problem with solving a maze is that we often only show others the successful path, the one that goes from start to finish, from entrance to exit. We exclude from our solution the paths that led us nowhere and the ones that gave us the knowledge we needed to make a better decision at the next fork in the road. We tell people how to do things—prescription—but we omit from our documentation the reasoning behind those instructions—description. Thinking of research, and the subsequent sharing of that research, as a labyrinthine process can help us bring the most valuable aspects of these two approaches together in our documentation.

The fundamentals of sharing
Bridging the gap between prescription and description isn’t so easy, though. This is due in part to the linearity of language: When we relate something with words, we have to present one fact after another, funneling a multidimensional journey across many paths into a one-dimensional line with one fact succeeding another. While this is helpful when we’re creating, say, deliberately straightforward step-by-step how-tos, it can also leave gaps in information and understanding that can cause inefficiencies and challenges later on.

As recipients of information, we’re often unaware of all of the decisions someone else made when they traversed the labyrinth. The narrative they construct—the solution to their own labyrinth—is the only true record of the research process they undertook, short of our own (potentially limited) extrapolations.

Expressed from a computer science point of view, on a whole graph—the labyrinth—we see just one path—the solution. Each vertex in the path, each knot along the way, not only hides a decision, but also obscures what lies ahead if we follow a particular bifurcation. If we question the solution and try to forge a new way forward, will we be doomed to stumble down already-trodden paths—to re-search, if you will—with no context for how to iterate or discover something new?

Sometimes the solution presented in documentation is so direct that it seems like there were no forks in the road to begin with. But that’s rarely the case. As engineering teams, we need to understand the validity of certain decisions and the rationale behind certain tasks or steps to be taken. Knowing the tradeoffs and alternative approaches that were considered along the way helps us to do that.

Consider this scenario: One day you notice that the SRE has disabled the caching servers, making requests to your website hit the database directly. At first glance, this may not make much sense. But what if, during a response to an outage, the SRE discovered that network latency between web servers and cache layers made responses to clients slower? Lost in a maze of alerts originating from various services, lists of logs leading nowhere, and graphs correlating to the wrong causes, finding the right service to restart or shut down feels like a stroke of luck. A postmortem documenting the steps the SRE took would tell a different story, illuminating their—and thus our—understanding of the outage and providing clarity and context that could help prevent future incidents.

Examples of this labyrinthine process appear throughout our day-to-day programming activities, often leading us to pore over documentation in search of paths forward.

Other examples of this labyrinthine process appear throughout our day-to-day programming activities, often leading us to pore over documentation in search of helpful paths forward. When we first join a team and have to approach their existing codebase, we might start with one of the controllers, then follow links to classes in the model. Perhaps there we find a query that filters users by membership type. We open the User class, thinking it might help explain what’s being stored in the database. There are different privileges for paying and non-paying users, so we jump to the project’s website to compare pricing tiers. Back at our IDE we’re reading YAML files, trying to find credentials to access the database so we can get a feel for the shape of the data. After a while we jump back to the model class, where we finally understand what that query meant.

We find ourselves with a pervasive conundrum: Tasks like choosing a JavaScript framework, solving outages in production, and learning an existing codebase all seem like labyrinthine activities. We have ways to talk about the process of discovery, of research, but we get stuck when it comes to communicating those findings without bogging down that communication. Could it help us to think about sharing knowledge as a labyrinthine process as well?

Labyrinthine aesthetics
In The Idea of the Labyrinth, Penelope Reed Doob presents wonderful research on labyrinths and their aesthetic value from classical antiquity through the Middle Ages. Of particular interest is how she correlates the canon of rhetoric to labyrinths, providing us with a framework for understanding how we can share a process that seems labyrinthine.


First, Reed Doob lays out the concept of inventio, the process of discovering existing ideas and going through prior research. “A good subject entails reshaping other people’s works or an arduous retracing of steps such as one might experience in a labyrinth,” she writes. We don’t want to rewrite an existing codebase; we want to understand what’s there so that we can contribute our own code. Similarly, we don’t want to deploy an entirely new system to production just to fix one alert. Instead, we want to map our current system, explore how servers relate to each other, and understand the various configuration options these systems have to offer. Likewise, it would be unwise to propose creating a new JavaScript framework without knowing what the current frameworks have to offer.

During the inventio phase we consider questions of where, what, how, and for what purpose. Where is the outage happening? To know that, we need to learn the layout of the servers. What is being affected? Website response times. How? Cache servers are being slow. What purpose do those serve? They prevent queries from going directly to the database. These questions, and the answers we uncover, are the lanterns that will illuminate our research journey.

Next, Reed Doob discusses dispositio, the arrangement of materials. Here, we want to document what we found during our research and arrange our findings in a pedagogically effective way. Going for the more straightforward path—presenting only the solution, not the process—might seem like the simpler approach, but as we’ve discussed, this risks leaving out important details. “The effective presentation of material demands something other than chronological narrative because the patterning of events is far more important than temporal sequence,” Reed Doob writes. Let’s look at an example of this patterning in the computer science literature.

In The Algorithm Design Manual, Steven S. Skiena uses this pattern of disposition whenever he presents one of his war stories. In one such story, titled “Give Me a Ticket on an Airplane,” he talks about being hired to help design an algorithm to find the cheapest available airfare from City x to City y. First, he offered a solution using Dijkstra’s shortest path algorithm, which was deemed useless due to certain aviation industry rules. Then he proposed building a matrix of m × n possible price pairs, but learned that it was too expensive. Skiena then realized that a priority queue might be the right data structure; he was getting close to an actual solution. He asked the company’s staff a few more questions, surfacing further needs and solutions. After exploring several avenues and iterating, he solved the problem.

Skiena could have given us the finished solution from the start. Instead, he shares the erroneous paths that led to insights that helped him refine the solution to the problem. Why? Because, per Reed Doob, this way of arranging the material has interesting pedagogical advantages: “Artificial order, in short, creates a digressive and meandering labyrinth for writers as they write and readers as they read.” (More on digression below.) This back and forth eases us toward the actual solution.

Finally, Reed Doob discusses elocutio, or expression. We’ve gathered facts and ordered them in a way that reflects our goals—now it’s time to share that material in a way that helps our recipients better understand our findings. This is, effectively, information architecture. Here, we must determine which of our bifurcations deserve amplification and which need abbreviation. I’ll echo Noah Iliinsky’s tips for effective visualizations, published in Beautiful Visualization: Looking at Data Through the Eyes of Experts:

The first area to consider is what knowledge you’re trying to convey, what question you’re trying to answer, or what story you’re trying to tell. […] The next consideration is how the visualization is going to be used. The readers and their needs, jargon, and biases must all be considered.

Reed Doob talks about how various amplificatory techniques can help us achieve our goal. Repetition allows us to restate what we have explained elsewhere in different words, enhancing clarity and comprehension. By explaining the structure of the database schema, for instance, we amplify readers’ understanding of the User class.

Another technique is digression, which, when used mindfully, can expand our understanding of why something is the way it is. Returning to the SRE example, taking some time to explain what caches are for and why they should satisfy certain performance properties could help us illuminate why we turned them off when the network latency made them prohibitive. (We could even include a side note to migrate the cache servers to a network where latency is not a problem.) But Reed Doob offers a warning about digression: “The more didactic one’s intent, the less digressions should rely on the hearer’s ingenuity to supply relevance, and vice versa.”

So, during elocutio, we must think about what areas of our research—our journey through the labyrinth—are relevant to our target audience. We won’t be able to document every single step we took and path we followed, and many of them will not be relevant anyway. But we can—and should—share those that will help others better understand the information we’re putting forward.

Conclusion: solving the labyrinth
We started with a couple of examples that illustrate how many of the exploratory activities related to programming can be considered labyrinthine. We confronted the difficulties of sharing our journey through the maze—difficulties that arise because the linearity of language forces us to share a path from what was once a graph, an act of compression that obscures critical details. But by seeing these processes as labyrinths, we can learn how to share our journey with our colleagues in a way that enhances their understanding of why we arrived at certain solutions.

The path is as important as the destination. Form becomes substance. The documentation and the labyrinth are one and the same.

This piece is a continuation of the thoughts laid out in a previously published version of this essay.

References
Doob, Penelope Reed. The Idea of the Labyrinth: from Classical Antiquity through the Middle Ages. Cornell University Press, 1992.

Skiena, Steven S. The Algorithm Design Manual. 2nd ed., Springer, 2010.

Steele, Julie, and Noah P. N. Iliinsky. Beautiful Visualization. O’Reilly, 2010.

About the author
Alvaro Videla is a developer advocate at Microsoft, and he organizes DuraznoConf. He is the coauthor of RabbitMQ in Action and has written for the Association for Computing Machinery.

@old_sound
