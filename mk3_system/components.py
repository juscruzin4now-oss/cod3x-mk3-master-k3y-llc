from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any


@dataclass(frozen=True)
class ComponentResult:
    component_id: str
    status: str
    details: dict[str, Any]


class MK3Component:
    component_id = "component"

    def execute(self, context: dict[str, Any]) -> ComponentResult:
        raise NotImplementedError

    def _ok(self, details: dict[str, Any]) -> ComponentResult:
        return ComponentResult(self.component_id, "ONLINE", details)


class EnvironmentInitializer(MK3Component):
    component_id = "environment"

    def execute(self, context: dict[str, Any]) -> ComponentResult:
        context["environment"] = {
            "device_connection": "VERIFIED",
            "authentication": "MASTER_KEY_ACCEPTED",
            "shell_state": "READY",
            "root_directory": "MOUNTED",
        }
        return self._ok(context["environment"])


class BaseFrameworkLoader(MK3Component):
    component_id = "framework"

    def execute(self, context: dict[str, Any]) -> ComponentResult:
        framework = {
            "base_package": "IMPORTED",
            "integrity_checksum": "PASSED",
            "dependencies": "RESOLVED",
            "heartbeat": "ACTIVE",
        }
        context["framework"] = framework
        context["heartbeat_started_at"] = datetime.now(timezone.utc).isoformat()
        return self._ok(framework)


class UploadChannelPreparer(MK3Component):
    component_id = "channels"

    def execute(self, context: dict[str, Any]) -> ComponentResult:
        channels = {
            "Channel_A_CoreLogic": "OPEN",
            "Channel_B_Interface": "OPEN",
            "Channel_C_External": "OPEN",
            "Channel_Status": "OPEN",
        }
        context["channels"] = channels
        return self._ok(channels)


class ModulePacketUploader(MK3Component):
    component_id = "packet"

    def execute(self, context: dict[str, Any]) -> ComponentResult:
        packet = {
            "packet_select": "READY",
            "packet_encoding": context.get("packet_encoding", "OPTIONAL"),
            "packet_transfer": "INITIATED",
            "await": "PACKET_RECEIVED",
        }
        context["packet"] = packet
        return self._ok(packet)


class PacketIntegrationVerifier(MK3Component):
    component_id = "integration"

    def execute(self, context: dict[str, Any]) -> ComponentResult:
        if "packet" not in context:
            return ComponentResult(
                self.component_id,
                "BLOCKED",
                {"reason": "Packet upload has not been initiated."},
            )

        integration = {
            "integration_logs": "CLEAN",
            "conflict_check": "NONE",
            "module_registration": "VERIFIED",
            "status": "MODULE_ONLINE",
        }
        context["integration"] = integration
        return self._ok(integration)


class NextPacketAdvancer(MK3Component):
    component_id = "advancement"

    def execute(self, context: dict[str, Any]) -> ComponentResult:
        advancement = {
            "loop": "CONTINUE",
            "channel_stability": "MONITOR",
            "adaptive_response": "TRACK",
            "close_channels": "AFTER_COMPLETION",
        }
        context["advancement"] = advancement
        return self._ok(advancement)
