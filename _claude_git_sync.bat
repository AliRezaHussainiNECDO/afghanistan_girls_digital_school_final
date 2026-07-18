@echo off
cd /d "C:\Users\Ali Reza HUSSAINI\StudioProjects\afghanistan_girls_digital_school"
(
echo === git add -A ===
git add -A
echo === git commit ===
git commit -m "Sync latest app state: fix API base URL + prod logging leak, plus pending feature/backend updates" -m "lib/core/network/api_client.dart: default API_BASE_URL now points to the live afghan-girls-school-api workers.dev Worker instead of an unrouted custom domain (fixes login/registration failing to connect)." -m "lib/core/network/network_providers.dart: enableLogging tied to kDebugMode so tokens/passwords are not logged in release builds." -m "Commits other pending local changes across features/, backend/routes, migrations 0025/0026, and new docs/ so GitHub reflects the current app state (triggers iOS CI build on push)."
echo === git push ===
git push origin master
echo === git log -1 ===
git log -1
echo === EXIT CODE %ERRORLEVEL% ===
) > "_claude_git_sync_output.log" 2>&1
echo DONE_MARKER > "_claude_git_sync_done.flag"
