FROM python:3.8.5-buster

# Install base packages
RUN apt-get update -y && apt-get upgrade -y && apt install -y \
    sudo \
    gnupg \
    wget \
    software-properties-common \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# Install base R
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E19F5F87128899B192B1A2C2AD5F960A256A04AF \
    && add-apt-repository 'deb https://cloud.r-project.org/bin/linux/debian buster-cran40/' \
    && apt-get update -y \
    && apt-get install -y \
        r-base \
        jags \
    && rm -rf /var/lib/apt/lists/*

# Install user yogi
RUN adduser yogi --disabled-password
RUN usermod -aG sudo yogi
RUN echo "%sudo   ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN echo "Set disable_coredump false" >> /etc/sudo.conf

USER yogi

WORKDIR /home/yogi
RUN mkdir -p /home/yogi/.R/lib
ENV R_LIBS="/home/yogi/.R/lib"

# Install poetry
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/1.1.0b3/get-poetry.py | python
ENV PATH "/home/yogi/.poetry/bin:/home/yogi/.local/bin:${PATH}"

# copy requirements separately from code for better caching
COPY requirements.R /home/yogi/requirements.R
COPY pyproject.toml poetry.lock /home/yogi/

# Install requirements
# N.B. We filter pywin32 from the requirements because for some reason poetry exports even though
#      we aren't on win32 and then pip complains that it can't find a compatible version
RUN poetry config virtualenvs.create false \
                && poetry export --without-hashes -f requirements.txt | grep -v pywin32 \
                |  poetry run pip install -r /dev/stdin \
                && poetry debug
RUN Rscript --vanilla /home/yogi/requirements.R

CMD ["bash"]