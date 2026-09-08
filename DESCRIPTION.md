# OpenHands on Cloudron

OpenHands is an AI-driven development agent and automation control center.

The app can execute commands in its container. Configure a strong `LOCAL_BACKEND_API_KEY` before exposing it to untrusted users. Agent workspaces and application state are stored in the Cloudron app data directory.

Nested Docker sandbox execution is not supported by this package. Use an external Agent Server backend when isolated execution is required.
