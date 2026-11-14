import QtQuick
import "file:///usr/share/omarchy/shell/plugins/polkit" as Upstream

Upstream.PolkitAgent {
  id: agent

  readonly property var panelWindow: {
    for (var i = 0; i < agent.data.length; i++)
      if (agent.data[i] && "exclusionMode" in agent.data[i]) return agent.data[i]
    return null
  }

  FocusedScreen { id: focusedScreen; hold: agent.dialogVisible }
  Binding { target: agent.panelWindow; property: "screen"; value: focusedScreen.screen; when: agent.panelWindow !== null }
}
