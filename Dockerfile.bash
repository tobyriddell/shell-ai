FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash
ENV USER=shelluser
ENV HOME=/home/$USER

# Update package list and install basic dependencies (excluding tmux - we'll build from source)
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    wget \
    git \
    neovim \
    asciinema \
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
    file \
    && rm -rf /var/lib/apt/lists/*

# Install Go 1.21+
RUN wget https://go.dev/dl/go1.25.1.linux-amd64.tar.gz && \
    echo "7716a0d940a0f6ae8e1f3b3f4f36299dc53e31b16840dbd171254312c41ca12e  go1.25.1.linux-amd64.tar.gz" | sha256sum -c - && \
    tar -C /usr/local -xzf go1.25.1.linux-amd64.tar.gz && \
    rm go1.25.1.linux-amd64.tar.gz

# Add Go to PATH
ENV PATH=$PATH:/usr/local/go/bin:/usr/bin/go

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

# Create a non-root user
RUN useradd -m -s /bin/bash $USER && \
    chown -R $USER:$USER /home/$USER && \
    echo "$USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Switch to the user
USER $USER
WORKDIR $HOME

# Install atuin
RUN curl --proto '=https' --tlsv1.2 -LsSf https://setup.atuin.sh | sh

# Create AI integration directory and local bin
RUN bash -c "mkdir -p ~/.config/shell-ai ~/.local/bin"

# Copy entire repository content
COPY --chown=$USER:$USER . /home/shelluser/

# ============================================================================
# Go Implementation (Primary) - Build and Install
# ============================================================================
# The Go implementation is the primary and recommended version.
# It provides better performance, conversational context, and enhanced features.

# Build the Go implementation (shell-ai-go)
RUN cd /home/shelluser/shell-ai-go && \
    /usr/local/go/bin/go mod download && \
    /usr/local/go/bin/go build -o build/shell-ai . && \
    chmod +x build/shell-ai

# Install the Go binary as the primary shell-ai command (switch to root for system-wide installation)
USER root
RUN cp /home/shelluser/shell-ai-go/build/shell-ai /usr/local/bin/shell-ai && \
    chmod +x /usr/local/bin/shell-ai

# Switch back to shelluser and create local symlink
USER $USER
RUN ln -sf /usr/local/bin/shell-ai /home/shelluser/.local/bin/shell-ai

# Note: tmux-selector functionality is now built into the main shell-ai binary
# No separate tmux-selector binary needed

# ============================================================================
# Legacy Bash Implementation (Deprecated)
# ============================================================================
# The bash scripts are kept for backward compatibility only.
# They are deprecated and will not receive new features.
# Users should migrate to the Go implementation.

# Copy AI integration scripts and providers to expected location (for legacy bash support)
# Note: These are deprecated in favor of the Go implementation
RUN cp -r /home/shelluser/scripts/* /home/shelluser/.config/shell-ai/ && \
    cp -r /home/shelluser/providers /home/shelluser/.config/shell-ai/ && \
    cp /home/shelluser/create_tmux_layout.sh /home/shelluser/.config/shell-ai/ && \
    chmod +x /home/shelluser/.config/shell-ai/*.sh && \
    chmod +x /home/shelluser/.config/shell-ai/providers/*.sh

# Copy configuration files to expected locations
RUN cp /home/shelluser/config/tmux.conf /home/shelluser/.tmux.conf && \
    cp /home/shelluser/config/bashrc-ai.sh /home/shelluser/.config/shell-ai/
# Copy the Go implementation helper script
RUN cp /home/shelluser/shell-ai-go/scripts/shell-ai-copy.sh /home/shelluser/.config/shell-ai/ && \
    chmod +x /home/shelluser/.config/shell-ai/shell-ai-copy.sh

# Verify scripts were copied correctly
RUN ls -la /home/shelluser/.config/shell-ai/

# ============================================================================
# Shell Integration Configuration
# ============================================================================
# Configure shell to use Go implementation as primary, with bash scripts as fallback

# Add local bin to PATH and AI integration to bash
# Note: bashrc-ai.sh has been updated to use Go implementation by default
RUN bash -c "echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc" && \
    bash -c "cat ~/.config/shell-ai/bashrc-ai.sh >> ~/.bashrc"

# Add Go shell-ai aliases and integration (Primary)
# These aliases point to the Go implementation
RUN bash -c "echo '' >> ~/.bashrc" && \
    bash -c "echo '# Shell AI Go Implementation (Primary)' >> ~/.bashrc" && \
    bash -c "echo 'alias ai=\"shell-ai ask\"' >> ~/.bashrc" && \
    bash -c "echo 'alias ai-interactive=\"shell-ai interactive\"' >> ~/.bashrc" && \
    bash -c "echo 'alias ai-setup=\"shell-ai setup\"' >> ~/.bashrc" && \
    bash -c "echo 'alias ai-test=\"shell-ai test\"' >> ~/.bashrc" && \
    bash -c "echo 'alias ai-go=\"shell-ai\"' >> ~/.bashrc" && \
    bash -c "echo '' >> ~/.bashrc"

# Add welcome message to bashrc
RUN bash -c "echo 'if [[ -f \$HOME/.config/shell-ai/welcome.sh ]]; then bash \$HOME/.config/shell-ai/welcome.sh; fi' >> ~/.bashrc"

# Set default command
CMD ["/bin/bash"] 
