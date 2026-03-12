/// TroubleshootScenario — a complete guided troubleshooting script
/// for one fault type, containing ordered steps the technician follows.
class TroubleshootScenario {
  final String               id;
  final String               title;
  final String               alertType;
  final String               description;
  final String               resolution;
  final List<TroubleshootStep> steps;

  const TroubleshootScenario({
    required this.id,
    required this.title,
    required this.alertType,
    required this.description,
    required this.resolution,
    required this.steps,
  });
}

/// TroubleshootStep — a single action the technician must perform.
class TroubleshootStep {
  final String  title;
  final String  instruction;
  final String? command;
  final String  expectedResult;
  final String? warningNote;
  final bool    isCritical;

  const TroubleshootStep({
    required this.title,
    required this.instruction,
    this.command,
    required this.expectedResult,
    this.warningNote,
    this.isCritical = false,
  });
}

/// TroubleshootData — static library of all troubleshooting scenarios.
class TroubleshootData {
  TroubleshootData._();

  static TroubleshootScenario getScenario({
    required String alertType,
    String deviceType = 'router',
  }) {
    if (alertType == 'mac_table_overflow' ||
        (alertType == 'high_memory' && deviceType == 'olt') ||
        alertType == 'mac_table_warning') {
      return _macTableOverflow;
    }
    switch (alertType) {
      case 'device_offline':  return _deviceOffline;
      case 'high_latency':    return _highLatency;
      case 'packet_loss':     return _packetLoss;
      case 'high_cpu':        return _highCpu;
      case 'high_memory':     return _highMemory;
      case 'interface_error': return _interfaceErrors;
      default:                return _genericConnectivity;
    }
  }

  // ── MAC Table Overflow ────────────────────────────────────────────────────

  static const TroubleshootScenario _macTableOverflow = TroubleshootScenario(
    id:          'mac_table_overflow',
    title:       'OLT MAC Table Overflow',
    alertType:   'mac_table_overflow',
    description: 'The OLT MAC address table is filling up. When it reaches '
        '100% capacity, new customers cannot connect and existing '
        'customers may experience intermittent disconnections.',
    resolution:  'The MAC table has been cleared and reorganised. Monitor '
        'the level over the next 30 minutes to confirm it stabilises '
        'below the warning threshold.',
    steps: [
      TroubleshootStep(
        title:       'Verify MAC Table Usage',
        instruction: 'Log into the OLT management interface via SSH or the '
            'web console. Run the command to check the current MAC address '
            'table size and compare it against the maximum.',
        command:        'show mac-address-table count',
        expectedResult: 'You should see the current count and the maximum '
            'allowed. If above 85% of the maximum, this confirms the overflow.',
        warningNote: 'Do not proceed with clearing the table until you have '
            'confirmed the count. Clearing unnecessarily causes a brief '
            'disconnection for all customers.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Check Which PON Ports Have the Most MACs',
        instruction: 'Identify which PON ports are contributing the most '
            'MAC addresses. High counts on a single port may indicate a '
            'rogue ONU or a switch behind an ONU.',
        command:        'show mac-address-table interface pon 0/1',
        expectedResult: 'Normally each residential port should have 1–5 MACs. '
            'Note down any ports with unusually high counts.',
        warningNote: 'A customer running a switch behind their ONU without '
            'informing the ISP is a common cause of MAC table bloat.',
      ),
      TroubleshootStep(
        title:       'Clear Aged-Out MAC Entries',
        instruction: 'Clear stale or aged-out MAC address entries from the '
            'table. This removes entries for devices no longer connected '
            'without affecting active customers.',
        command:        'clear mac-address-table dynamic',
        expectedResult: 'The MAC table count should drop by 20–40%. Active '
            'customers will re-learn within 10–15 seconds.',
        warningNote: 'All customers experience a brief 5–15 second '
            'disconnection. Inform the NOC before proceeding during peak hours.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Verify MAC Count After Clearing',
        instruction: 'Wait 2 minutes after clearing then check the MAC '
            'table count again to confirm it has dropped to a safe level.',
        command:        'show mac-address-table count',
        expectedResult: 'The count should now be below 70% of the maximum. '
            'If still above 85% after 2 minutes, VLAN segmentation is needed.',
      ),
      TroubleshootStep(
        title:       'Set MAC Limit Per PON Port',
        instruction: 'Configure a per-port MAC address limit to prevent any '
            'single customer from consuming excessive table entries. '
            'A limit of 8 MACs per residential ONU is standard.',
        command:        'interface pon 0/1\nmac-address-table limit 8',
        expectedResult: 'The port MAC limit is set. Any ONU that exceeds '
            'this limit will have new MAC addresses blocked.',
        warningNote: 'Apply this to all PON ports as a preventive measure.',
      ),
      TroubleshootStep(
        title:       'Verify Customer Connectivity',
        instruction: 'After all changes are complete, verify that customers '
            'are connecting and getting correct IP addresses. Ping a sample '
            'of customer ONUs.',
        command:        'ping onu-ip 192.168.100.10 count 10',
        expectedResult: 'All pinged ONUs should respond with low latency '
            'below 5ms. Close the alert once confirmed.',
      ),
    ],
  );

  // ── Device Offline ────────────────────────────────────────────────────────

  static const TroubleshootScenario _deviceOffline = TroubleshootScenario(
    id:          'device_offline',
    title:       'Device Unreachable',
    alertType:   'device_offline',
    description: 'The device is not responding to ICMP ping requests. '
        'This could be a power issue, network issue, or hardware fault.',
    resolution:  'The device is back online and responding to pings. '
        'Monitor for the next 15 minutes to confirm stability.',
    steps: [
      TroubleshootStep(
        title:       'Check Physical Power',
        instruction: 'Physically verify that the device has power. '
            'Check that the power LED is on and the device is not '
            'showing any fault indicators.',
        expectedResult: 'Power LED is solid green. No alarm LEDs active.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Check Upstream Link',
        instruction: 'Verify that the upstream network connection is active. '
            'Check the link LED on the port connecting this device to the '
            'rest of the network.',
        expectedResult: 'Link LED is solid or blinking, indicating an '
            'active network connection.',
      ),
      TroubleshootStep(
        title:       'Ping from Adjacent Device',
        instruction: 'From another device on the same network segment, '
            'attempt to ping this device to rule out a routing issue.',
        command:        'ping 192.168.1.20 count 10',
        expectedResult: 'If pings succeed from the adjacent device but not '
            'from the monitoring server, the issue is routing — not hardware.',
      ),
      TroubleshootStep(
        title:       'Restart the Device',
        instruction: 'If all above steps show no issue but the device is '
            'still unreachable, perform a controlled restart.',
        command:        'reboot',
        expectedResult: 'Device restarts within 2–3 minutes and begins '
            'responding to pings.',
        warningNote: 'A power cycle will disconnect all customers served by '
            'this device. Inform NOC before proceeding.',
        isCritical: true,
      ),
    ],
  );

  // ── High Latency ──────────────────────────────────────────────────────────

  static const TroubleshootScenario _highLatency = TroubleshootScenario(
    id:          'high_latency',
    title:       'High Latency',
    alertType:   'high_latency',
    description: 'Round-trip latency is consistently above the 200ms '
        'threshold, causing slow response times for customers.',
    resolution:  'Latency has returned to normal levels below 50ms.',
    steps: [
      TroubleshootStep(
        title:       'Check Bandwidth Utilisation',
        instruction: 'Check the interface utilisation on this device. '
            'High latency is often caused by a link running near 100%.',
        command:        'show interface bandwidth-utilisation',
        expectedResult: 'Utilisation should be below 80%. Above 90% '
            'indicates the link is saturated and causing queuing delays.',
      ),
      TroubleshootStep(
        title:       'Check for Routing Loops',
        instruction: 'Run a traceroute from the monitoring server to this '
            'device. Look for packets bouncing between the same hops.',
        command:        'traceroute 192.168.1.20',
        expectedResult: 'A clean traceroute shows a short, direct path '
            'with each hop increasing in latency.',
      ),
      TroubleshootStep(
        title:       'Apply Traffic Shaping',
        instruction: 'If a specific customer or service is consuming '
            'disproportionate bandwidth, apply QoS policies.',
        command:        'ip access-list extended THROTTLE\npermit ip any any dscp default',
        expectedResult: 'Latency drops as bandwidth-hungry traffic is '
            'deprioritised and network queues clear.',
      ),
    ],
  );

  // ── Packet Loss ───────────────────────────────────────────────────────────

  static const TroubleshootScenario _packetLoss = TroubleshootScenario(
    id:          'packet_loss',
    title:       'High Packet Loss',
    alertType:   'packet_loss',
    description: 'Packet loss above 5% is degrading customer experience '
        'with dropped connections and poor voice/video quality.',
    resolution:  'Packet loss has returned to below 1%.',
    steps: [
      TroubleshootStep(
        title:       'Check Physical Interface Errors',
        instruction: 'Check the interface error counters on the device. '
            'CRC errors, input errors, and runts indicate a physical layer problem.',
        command:        'show interface errors',
        expectedResult: 'Error counters should be zero or very low. '
            'High CRC errors indicate a bad cable or SFP.',
      ),
      TroubleshootStep(
        title:       'Check Cable and SFP',
        instruction: 'Physically inspect the cable connecting this device '
            'to the upstream network. Check the SFP optical power levels.',
        command:        'show interface optical-power',
        expectedResult: 'Optical power should be within the acceptable '
            'receive range for the SFP type. Replace degraded SFPs.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Check for Duplex Mismatch',
        instruction: 'Verify that both ends of the link are configured '
            'for the same duplex mode. A mismatch causes late collisions '
            'and high packet loss.',
        command:        'show interface duplex',
        expectedResult: 'Both ends should show full-duplex at the same speed.',
      ),
    ],
  );

  // ── High CPU ──────────────────────────────────────────────────────────────

  static const TroubleshootScenario _highCpu = TroubleshootScenario(
    id:          'high_cpu',
    title:       'High CPU Usage',
    alertType:   'high_cpu',
    description: 'CPU usage is above 80%, which can cause management '
        'plane failures, slow SNMP responses, and packet drops.',
    resolution:  'CPU usage has returned to normal levels below 60%.',
    steps: [
      TroubleshootStep(
        title:       'Identify Top CPU Processes',
        instruction: 'Check which processes are consuming the most CPU. '
            'A routing protocol recalculation or a broadcast storm are '
            'common causes of sudden CPU spikes.',
        command:        'show processes cpu sorted',
        expectedResult: 'You should identify one or two processes consuming '
            'abnormal CPU. Normal routing processes should be below 5% each.',
      ),
      TroubleshootStep(
        title:       'Check for Broadcast Storm',
        instruction: 'A broadcast storm can flood the CPU with packets. '
            'Check broadcast and multicast packet rates on all interfaces.',
        command:        'show interface counters broadcast',
        expectedResult: 'Broadcast rates should be below 1000 packets per '
            'second on any given interface.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Apply CPU Protection Policies',
        instruction: 'If a specific traffic type is overwhelming the CPU, '
            'apply control-plane policing to rate-limit it.',
        command:        'control-plane\nservice-policy input COPP_POLICY',
        expectedResult: 'CPU usage drops as the policing policy absorbs '
            'the burst traffic before it reaches the CPU.',
      ),
    ],
  );

  // ── High Memory ───────────────────────────────────────────────────────────

  static const TroubleshootScenario _highMemory = TroubleshootScenario(
    id:          'high_memory',
    title:       'High Memory Usage',
    alertType:   'high_memory',
    description: 'Memory usage is above 85%, risking process crashes '
        'and service instability if it reaches 100%.',
    resolution:  'Memory usage has stabilised at a safe level.',
    steps: [
      TroubleshootStep(
        title:       'Check Memory-Consuming Processes',
        instruction: 'Identify which processes are using the most memory.',
        command:        'show processes memory sorted',
        expectedResult: 'Normal operation should show no single process '
            'consuming more than 30% of available memory.',
      ),
      TroubleshootStep(
        title:       'Check Routing Table Size',
        instruction: 'A very large routing table can consume significant '
            'memory. Check how many routes are in the table.',
        command:        'show ip route summary',
        expectedResult: 'The route count should be within the expected '
            'range for your network size.',
      ),
      TroubleshootStep(
        title:       'Schedule Maintenance Restart',
        instruction: 'If memory continues to grow over time, a controlled '
            'restart during a maintenance window will clear the leak.',
        command:        'reload in 120',
        expectedResult: 'Device restarts cleanly and memory returns to '
            'baseline levels within 5 minutes of boot.',
        warningNote: 'Schedule this during a low-traffic maintenance window.',
        isCritical: true,
      ),
    ],
  );

  // ── Interface Errors ──────────────────────────────────────────────────────

  static const TroubleshootScenario _interfaceErrors = TroubleshootScenario(
    id:          'interface_error',
    title:       'Interface Errors',
    alertType:   'interface_error',
    description: 'High error rates on one or more interfaces are causing '
        'packet drops and service degradation.',
    resolution:  'Interface error counters have returned to zero.',
    steps: [
      TroubleshootStep(
        title:       'Identify the Affected Interface',
        instruction: 'Check which specific interface is generating errors.',
        command:        'show interface counters errors',
        expectedResult: 'You should see which interface has non-zero error '
            'counters. Note the interface name.',
      ),
      TroubleshootStep(
        title:       'Check Cable and SFP Health',
        instruction: 'Physically inspect the cable on the affected interface. '
            'Check optical power levels if using fibre.',
        command:        'show interface optical-power',
        expectedResult: 'Optical levels within acceptable range. '
            'Replace any degraded cables or SFPs.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Clear Counters and Monitor',
        instruction: 'Clear the error counters and monitor for 10 minutes '
            'to see if errors recur after replacing suspect hardware.',
        command:        'clear counters',
        expectedResult: 'Error counters remain at zero after clearing. '
            'If they climb again immediately, the issue is ongoing.',
      ),
    ],
  );

  // ── Generic Connectivity ──────────────────────────────────────────────────

  static const TroubleshootScenario _genericConnectivity = TroubleshootScenario(
    id:          'generic',
    title:       'Connectivity Issue',
    alertType:   'generic',
    description: 'A connectivity issue has been detected on this device. '
        'Follow these general steps to identify and resolve the cause.',
    resolution:  'The connectivity issue has been resolved.',
    steps: [
      TroubleshootStep(
        title:       'Verify Device is Reachable',
        instruction: 'Ping the device from the monitoring server and from '
            'an adjacent device to determine the scope of the issue.',
        command:        'ping 192.168.1.1 count 20',
        expectedResult: 'Device responds to all 20 pings with latency '
            'below 50ms.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Check Interface Status',
        instruction: 'Verify all interfaces are in the expected up state.',
        command:        'show interface status',
        expectedResult: 'All expected interfaces show as connected '
            'and operating at the correct speed.',
      ),
      TroubleshootStep(
        title:       'Review Recent Logs',
        instruction: 'Check the device system log for any error messages '
            'or warnings that coincide with when the alert was triggered.',
        command:        'show log | last 50',
        expectedResult: 'No critical error messages in the log. Any '
            'warnings noted for further investigation.',
      ),
    ],
  );
}
