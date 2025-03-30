# Use an official Ubuntu base image
FROM ubuntu:latest  

# Set environment variables (avoid interactive prompts during installation)
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/conda/bin:$PATH"

# Update and install necessary dependencies
RUN apt update && apt install -y \
    less \
    r-base \
    gawk \
    wget \
    gzip \
    tar \
    curl \
    jq \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda (a lightweight version of Anaconda)
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /miniconda.sh && \
    bash /miniconda.sh -b -p /opt/conda && \
    rm /miniconda.sh

# Ensure Conda is initialized
RUN /opt/conda/bin/conda init

# Install IQ-TREE2 from Bioconda
RUN /opt/conda/bin/conda install -c bioconda -y iqtree

# Install yq (for YAML parsing)
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && \
    chmod +x /usr/local/bin/yq

# Set the working directory inside the container
WORKDIR /app  

# Copy the script and config file into the container
COPY assignment.sh .
COPY config.yaml .

# Ensure the script is executable
RUN chmod +x assignment.sh  

# Define the command to run the script
CMD ["./assignment.sh"]
