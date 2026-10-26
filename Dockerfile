FROM ghcr.io/nesquena/hermes-webui:latest AS webui
FROM nousresearch/hermes-agent:latest AS agent
FROM webui
COPY --from=agent /opt/hermes /opt/hermes
# uv override requirements for the container init's `uv pip install -e "/opt/hermes[all]"`
# (upstream: nesquena/hermes-webui#8524, NousResearch/hermes-agent#143313). Since agent
# v0.22.5 the source pins Pillow==13.0.0 while browser-harness==0.1.13 pins pillow==12.3.0;
# the agent resolves that in [tool.uv] override-dependencies, but `uv pip install` never
# reads a project's [tool.uv] table, so the init's resolve fails and the container
# crash-loops ("No solution found when resolving dependencies" -> "Exiting script").
# UV_OVERRIDE is honoured by every uv invocation in the init, including the first
# requirements.txt install (cryptography==50.0.1 still satisfies its >=42.0).
COPY uv-overrides.txt /opt/uv-overrides.txt
RUN chmod a+r /opt/uv-overrides.txt
ENV UV_OVERRIDE=/opt/uv-overrides.txt
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
# Build-time guard: the override must make the staged agent resolvable, otherwise the
# regression only surfaces as a crash loop on the deployed container. --dry-run resolves the
# [all] graph and installs nothing. The exit status is propagated explicitly because a
# pipeline (`... | tail`) would report tail's status and swallow uv's failure.
RUN uv pip install --dry-run --python /opt/hermes/.venv/bin/python \
      --override /opt/uv-overrides.txt -e "/opt/hermes[all]" > /tmp/uv-override-check.log 2>&1; \
    status=$?; tail -3 /tmp/uv-override-check.log; exit $status
