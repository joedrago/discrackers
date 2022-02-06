Place all of your comics in here, organized neatly into subdirectories. A great way to do this is to leverage Crackers' `merge` command, such as:

        crackers merge -m path/to/this/root some/other/dir/*.cbr some/other/dir/*.cbz

This will show you a list of commands that would be executed to move/organize the listed files into the `root` dir. If you are happy with its results, rerun the command and add `-x` to the end of it, such as:

        crackers merge -m path/to/this/root some/other/dir/*.cbr some/other/dir/*.cbz -x

This will actually perform the moves.
