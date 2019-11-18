# lapse

A simple tool for visualizing the evolution of a version-controlled text file.

---

At some point, I observed that large blobs of text can resemble land- and cityscapes when viewed at a certain angle and distance. My first attempt to capture this observation came in the form of a filter manually applied to an image of an entry in one of my journals:

<img src="readme_assets/citytext.png" alt="Image of blurred text, oriented to resemble a cityscape" width="50%" height="50%"/>

It wasn't long before I realized that, given the history of transformations applied to a bit of text, it would be possible to create a sort of flip-book visualization of that text reminiscent of an evolving landscape. `lapse` is a tiny tool, borne of other tools, capable of producing such a visualization. This is what it looks like; for this example, I chose a file with thousands of lines that had been touched by hundreds of minds over nearly ten years:

![Visualization of the evolution of a very large, very old text file](readme_assets/evolution.gif)

I've used a combination of readily available command-line tools such as `git`, `watch`,  and `sed`, in conjunction with some features of the `iTerm2** terminal application, to achieve this.

I think the results are slightly beautiful.

## Usage
This tool currently expects to be executed from the `iTerm2` application on a Mac, as it relies on the `iTerm2` Applescript API to programmatically generate a sequence of "observer" sessions using a particular UI profile (which manipulates the visual aesthetic of the animated text).

To run this on your own machine, you'll need to install `iTerm2` and create a profile called "TINY". I named it this because for a file as large as the one I was targeting during development, I needed the rendered font size to be as small as possible in order to reasonably fit the entire animation on one screen. You can configure this profile however you like, but currently the name is hard-coded and must be "TINY".

```shell
##
# Example usage:
#     TARGET_PROJECT=~/github/cool_project TARGET_FILE=app/models/cool_model.rb SPEED=0.05 ./lapse.sh
#
# Required arguments:
#     TARGET_PROJECT - a path (relative or absolute) to the base Git repository of TARGET_FILE
#        TARGET_FILE - a path (relative to TARGET_PROJECT, or absolute) to the file to visualize
#
#
# Optional arguments:
#     TARGET_REVISION_RANGE - [default: "master"] a Git revision range (following the format accepted
#                             by `git log`) indicating the slice of project history to visualize;
#                             specifying a single commit or branch name implicitly indicates the
#                             beginning of the range is the first reachable commit containing TARGET_FILE
#                     SPEED - [default: 0.2] a numeric value (floating point accepted) measuring the
#                             desired time in seconds between each "frame" of the visualization
##
```


## Ideas for improvement
- parameterize the name of the `iTerm2` profile to use for configuring the animation aesthetic
- find a way to remove dependency on `iTerm2`, or add support for default the `Terminal` application and make it configurable
- add support for generating a screen capture of the resulting animation
