# Cluster-Bash-
A bash script to control jobs in a ssh cluster. The script is modular so specific applications can use some of its functionalities to adapt to different kinds of parallelization. 

## Synopsis
		 cluster.sh [-h] [-c -ac -p -ap <input string>] [-as] [-f] [-t] [-e <job and input] [-s <string>] [-m] [-r <node>] [-w]
## Options
* **-h**  This help text
* **-c** Checks if input is acceptable
* **-ac** Checks if cluster-specific input is acceptable
* **-p** Parses input
* **-ap** Parses cluster-specific input
* **-as** Assembles input (i.e. Joins both input parses)
* **-f** Free nodes. Refreshes the available nodes queue by attending to all free requests (sent by each process). These requests are stored in a separate queue file.
* **-t**  Runs all tests (bug - Probably outdated due to recent changes)
* **-e** External add. Adds command to queue *immeadetly*. Only checks basic syntax. With great powers come great responsibilities
* **-s** Seek both in queue and in all nodes for instances of a given process (or substring of a given process name)
* **-m** Moves the process queue by submitting a job to each free node.
* **-r** Request the freeing of a node. This should be used by a job upon completion to free its current node and communicate its completion.
* **-w** Writes the file listing all available nodes and how many jobs the user can commit to each node. This command is quite slow so try to use it only once and then make your jobs communicate their completion via the -r flag

