First run: 

>sudo docker build --no-cache -t iqtree-container . 

on a unix shell to build the docker image and then run:

>sudo docker run --rm -v $(pwd):/app iqtree-container

to run the docker image you created and thus run the assignment.sh script through the docker file

Afterwards, read the report.txt
