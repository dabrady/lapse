# lapse

A simple tool for visualizing the evolution of a version-controlled text file.

---

At some point, I observed that large blobs of text can resemble land- and cityscapes when viewed at a certain angle and distance. My first attempt to capture this observation came in the form of a filter manually applied to an image of an entry in one of my journals:

<img src="readme_assets/citytext.png" alt="Image of blurred text, oriented to resemble a cityscape" width="50%" height="50%"/>

It wasn't long before I realized that, given the history of transformations applied to a bit of text, it would be possible to create a sort of flip-book visualization of that text reminiscent of an evolving landscape. `lapse` is a tiny tool, borne of other tools, capable of producing such a visualization. This is what it looks like; for this example, I chose a file that had been touched by hundreds of minds over nearly ten years:

![Visualization of the evolution of a very large, very old text file](readme_assets/evolution.gif)

I've used a combination of readily available command-line tools such as `git`, `watch`,  and `sed`, in conjunction with some features of the `iTerm2` terminal application, to achieve this.

I think the results are slightly beautiful.
