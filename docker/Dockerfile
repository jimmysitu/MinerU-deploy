FROM vllm/vllm-openai:v0.11.2

ARG MINERU_VERSION
ARG MINERU_RELEASE_TAG

LABEL org.opencontainers.image.title="MinerU API runtime"
LABEL org.opencontainers.image.description="MinerU server (mineru-api) without bundled model weights"
LABEL org.opencontainers.image.vendor="MinerU"
LABEL org.opencontainers.image.version="${MINERU_VERSION}"
LABEL org.opencontainers.image.ref.name="${MINERU_RELEASE_TAG}"

RUN apt-get update && \
    apt-get install -y \
        fonts-noto-core \
        fonts-noto-cjk \
        fontconfig \
        libgl1 && \
    fc-cache -fv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install -U "mineru[core]==${MINERU_VERSION}" --break-system-packages && \
    python3 -m pip cache purge

RUN mkdir -p /models/pipeline /models/vlm /etc/mineru /data && \
    printf '%s\n' \
    '{' \
    '  "latex-delimiter-config": {' \
    '    "display": {' \
    '      "left": "$$",' \
    '      "right": "$$"' \
    '    },' \
    '    "inline": {' \
    '      "left": "$",' \
    '      "right": "$"' \
    '    }' \
    '  },' \
    '  "llm-aided-config": {' \
    '    "title_aided": {' \
    '      "enable": false' \
    '    }' \
    '  },' \
    '  "models-dir": {' \
    '    "pipeline": "/models/pipeline",' \
    '    "vlm": "/models/vlm"' \
    '  },' \
    '  "config_version": "1.3.1"' \
    '}' > /etc/mineru/mineru.json

ENV MINERU_MODEL_SOURCE=local
ENV MINERU_TOOLS_CONFIG_JSON=/etc/mineru/mineru.json
ENV MINERU_API_OUTPUT_ROOT=/data/output

EXPOSE 8000

ENTRYPOINT ["mineru-api"]
CMD ["--host", "0.0.0.0", "--port", "8000"]
