FROM ghcr.io/nesquena/hermes-webui:latest AS webui
FROM nousresearch/hermes-agent:latest AS agent
FROM webui
COPY --from=agent /opt/hermes /opt/hermes
# Agent v0.21.6+ (PM managed runtime): /opt/hermes/.venv is the sealed dependency
# environment the agent modules load from. Deleting it breaks every chat turn
# ("AIAgent not available ... ModuleNotFoundError: dotenv") while the server still
# starts and passes its pre-flight check, so keep it — drop only VCS/build leftovers.
RUN rm -rf /opt/hermes/.git /opt/hermes/__pycache__
# make agent install lock readable: hermeswebui staging rsync must read it (base image ships root:600)
RUN chmod a+r /opt/hermes/tools/.install.lock
# Both base images ship a python3 at /usr/local/bin, but the webui base's is 3.12
# while the sealed agent environment is built for 3.14. Re-point the venv
# interpreter at the agent image's own 3.14 store python (target of
# pm-runtime/bin/python), then prove the dependency set is importable.
RUN ln -sf "$(readlink /opt/hermes/pm-runtime/bin/python)" /opt/hermes/.venv/bin/python \
    && /opt/hermes/.venv/bin/python -c "import sys; assert sys.version_info[:2] == (3, 14), sys.version" \
    && /opt/hermes/.venv/bin/python -c "import importlib.util as u; missing = [m for m in ('dotenv', 'ruamel.yaml', 'openai', 'cryptography', 'pydantic_core') if u.find_spec(m) is None]; assert not missing, missing"
# Run the WebUI server (and the managed scripts it re-execs) under the sealed
# interpreter: only it holds both the webui deps (cryptography; pyyaml with the
# ruamel fallback) and the agent module graph. Assert the launch line so an
# upstream init rename fails the build loudly instead of silently regressing.
RUN set -e; for f in /hermeswebui_init.bash /apptoo/docker_init.bash /app/docker_init.bash; do \
      [ -f "$f" ] || continue; \
      sed -i 's#cd /app; python server.py#cd /app; /opt/hermes/.venv/bin/python server.py#' "$f"; \
      grep -q '/opt/hermes/.venv/bin/python server.py' "$f"; \
      ! grep -q 'cd /app; python server.py' "$f"; \
    done \
    && grep -q '/opt/hermes/.venv/bin/python server.py' /hermeswebui_init.bash /apptoo/docker_init.bash
ENV HERMES_WEBUI_AGENT_DIR=/opt/hermes
ENV HERMES_WEBUI_PYTHON=/opt/hermes/.venv/bin/python
RUN test -f /opt/hermes/pyproject.toml && test -f /apptoo/server.py
