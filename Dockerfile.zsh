FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/zsh
ENV USER=shelluser
ENV HOME=/home/$USER

# Update package list and install basic dependencies (excluding tmux - we'll build from source)
RUN apt-get update && apt-get install -y \
    zsh \
    curl \
    wget \
    git \
    neovim \
    ripgrep \
    bsdextrautils \
    build-essential \
    sudo \
    locales \
    ca-certificates \
    jq \
    python3 \
    python3-pip \
    python3-venv \
    libevent-dev \
    libncurses-dev \
    bison \
    pkg-config \
    autotools-dev \
    automake \
    && rm -rf /var/lib/apt/lists/*

# Build and install tmux 3.5a from source with checksum verification, we need at least 3.5 to fix the 'split-window -p' bug
RUN cd /tmp && \
    wget https://github.com/tmux/tmux/releases/download/3.5a/tmux-3.5a.tar.gz && \
    echo "16216bd0877170dfcc64157085ba9013610b12b082548c7c9542cc0103198951  tmux-3.5a.tar.gz" | sha256sum -c - && \
    tar -xzf tmux-3.5a.tar.gz && \
    cd tmux-3.5a && \
    ./configure --prefix=/usr/local && \
    make -j$(nproc) && \
    make install && \
    cd / && \
    rm -rf /tmp/tmux-3.5a* && \
    ldconfig

# Set up locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Create a non-root user with zsh as default shell
RUN useradd -m -s /bin/zsh $USER && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to the user
USER $USER
WORKDIR $HOME

# Install atuin
RUN curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

# Configure zsh to use atuin
RUN echo 'eval "$(atuin init zsh)"' >> /home/shelluser/.zshrc

# Create AI integration directory
RUN zsh -c "mkdir -p ~/.config/shell-ai"

# Copy entire repository content
COPY --chown=$USER:$USER . /home/shelluser/

# Copy AI integration scripts to expected location and make them executable
RUN cp -r /home/shelluser/scripts/* /home/shelluser/.config/shell-ai/ && \
    chmod +x /home/shelluser/.config/shell-ai/*.sh

# Copy configuration files to expected locations
RUN cp /home/shelluser/config/tmux.conf /home/shelluser/.tmux.conf && \
    cp /home/shelluser/config/zshrc-ai.sh /home/shelluser/.config/shell-ai/ && \
    cp /home/shelluser/config/ai-config.example.json /home/shelluser/.config/shell-ai/config.json

# Verify scripts were copied correctly
RUN ls -la /home/shelluser/.config/shell-ai/

# Add AI integration to zsh
RUN zsh -c "cat ~/.config/shell-ai/zshrc-ai.sh >> ~/.zshrc"

# Add welcome message to zshrc
RUN zsh -c "echo '' >> ~/.zshrc && echo 'if [[ -f \$HOME/.config/shell-ai/welcome.sh ]]; then zsh \$HOME/.config/shell-ai/welcome.sh; fi' >> ~/.zshrc"

# Set default command
CMD ["/bin/zsh"] 