/// TroubleshootScenario represents a specific fault type with a
/// complete step-by-step resolution guide.
class TroubleshootScenario {
  final String             id;
  final String             title;
  final String             description;
  final String             alertType;
  final List<TroubleshootStep> steps;
  final String             resolution; // shown when all steps are complete

  const TroubleshootScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.alertType,
    required this.steps,
    required this.resolution,
  });
}

/// A single step in the troubleshooting wizard.
class TroubleshootStep {
  final String  title;
  final String  instruction;     // what to do
  final String  expectedResult;  // what you should see if it works
  final String? warningNote;     // optional caution to display
  final String? command;         // optional CLI command to run on the device
  final bool    isCritical;      // if true the wizard warns before skipping

  const TroubleshootStep({
    required this.title,
    required this.instruction,
    required this.expectedResult,
    this.warningNote,
    this.command,
    this.isCritical = false,
  });
}


class TroubleshootData {
  TroubleshootData._();

  /// Returns the correct scenario for a given alert type and device type.
  /// Falls back to the generic connectivity scenario if no match found.
  static TroubleshootScenario getScenario({
    required String alertType,
    String deviceType = 'router',
  }) {
    // OLT-specific MAC table overflow scenario
    if (alertType == 'mac_table_overflow' ||
        (alertType == 'high_memory' && deviceType == 'olt') ||
        alertType == 'mac_table_warning') {
      return _macTableOverflow;
    }

    switch (alertType) {
      case 'device_offline':   return _deviceOffline;
      case 'high_latency':     return _highLatency;
      case 'packet_loss':      return _packetLoss;
      case 'high_cpu':         return _highCpu;
      case 'high_memory':      return _highMemory;
      case 'interface_error':  return _interfaceErrors;
      default:                 return _genericConnectivity;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MAC Table Overflow — OLT specific
  // This is the most important scenario for fibre ISPs.
  // ─────────────────────────────────────────────────────────────────────────
  static const TroubleshootScenario _macTableOverflow =
      TroubleshootScenario(
    id:          'mac_table_overflow',
    title:       'OLT MAC Table Overflow',
    alertType:   'mac_table_overflow',
    description: 'The OLT MAC address table is filling up. When it reaches '
        '100% capacity, new customers cannot connect and existing '
        'customers may experience intermittent disconnections and '
        'severely reduced internet speeds. Resolve this immediately.',
    resolution:  'The MAC table has been cleared and reorganised. Monitor '
        'the table level over the next 30 minutes to confirm it '
        'stabilises below the warning threshold. If it fills rapidly '
        'again, VLAN segmentation is required as a permanent fix.',
    steps: [

      TroubleshootStep(
        title:       'Verify MAC Table Usage',
        instruction: 'Log into the OLT management interface via SSH or '
            'the web console. Run the command to check the current '
            'MAC address table size and compare it against the maximum.',
        command:     'show mac-address-table count',
        expectedResult: 'You should see the current count and the maximum '
            'allowed. If the current count is above 85% of the maximum, '
            'this confirms the overflow condition.',
        warningNote: 'Do not proceed with clearing the table until you '
            'have confirmed the count. Clearing it unnecessarily causes '
            'a brief disconnection for all connected customers.',
        isCritical: true,
      ),

      TroubleshootStep(
        title:       'Check Which PON Ports Have the Most MACs',
        instruction: 'Identify which PON ports are contributing the most '
            'MAC addresses. High MAC counts on a single PON port may '
            'indicate a rogue ONU broadcasting multiple MACs, or a '
            'switch behind an ONU connecting many devices.',
        command:     'show mac-address-table interface pon 0/1',
        expectedResult: 'You will see a list of MAC addresses learned on '
            'each PON port. Look for any port with an unusually high '
            'count — normally each port should have 1 to 5 MACs for '
            'residential customers.',
        warningNote: 'A customer running a switch or router behind their '
            'ONU without informing the ISP is a common cause of MAC '
            'table bloat. Note down any suspicious ports.',
      ),

      TroubleshootStep(
        title:       'Clear Aged-Out MAC Entries',
        instruction: 'Clear stale or aged-out MAC address entries from '
            'the table. This removes entries for devices that are no '
            'longer connected without affecting active customers. '
            'Run the clear command on the OLT.',
        command:     'clear mac-address-table dynamic',
        expectedResult: 'The MAC table count should drop significantly — '
            'typically by 20 to 40 percent. Active customers '
            'will re-learn immediately within a few seconds. '
            'Their internet connectivity will be restored within '
            '10 to 15 seconds of the clear.',
        warningNote: 'All customers will experience a brief disconnection '
            'of 5 to 15 seconds while their devices re-learn. '
            'Inform the NOC before proceeding if this is during '
            'peak hours.',
        isCritical: true,
      ),

      TroubleshootStep(
        title:       'Verify MAC Count After Clearing',
        instruction: 'Wait 2 minutes after clearing then check the MAC '
            'table count again to confirm it has dropped to a safe '
            'level. The count will rise as active customers re-learn '
            'but should stabilise well below the warning threshold.',
        command:     'show mac-address-table count',
        expectedResult: 'The count should now be below 70% of the maximum. '
            'If it is still above 85% after 2 minutes, there are '
            'too many active devices and VLAN segmentation is needed.',
      ),

      TroubleshootStep(
        title:       'Set MAC Limit Per PON Port',
        instruction: 'Configure a per-port MAC address limit to prevent '
            'any single customer from consuming excessive table entries. '
            'A limit of 8 MAC addresses per residential ONU is standard. '
            'Commercial customers may need a higher limit of 20 to 50.',
        command:     'interface pon 0/1\nmac-address-table limit 8',
        expectedResult: 'The port MAC limit is now set. Any ONU that '
            'exceeds this limit will have new MAC addresses blocked, '
            'protecting the overall table from overflow.',
        warningNote: 'Apply this to all PON ports, not just the ones '
            'with high counts. This is a preventive measure.',
      ),

      TroubleshootStep(
        title:       'Create VLAN Segments (Long-Term Fix)',
        instruction: 'If the MAC table fills repeatedly, the network '
            'needs to be segmented into VLANs. Each VLAN has its own '
            'MAC table scope, effectively multiplying your capacity. '
            'Create separate VLANs for residential, business, and '
            'management traffic. This requires a maintenance window.',
        command:     'vlan 100\n  name residential\nvlan 200\n  name business',
        expectedResult: 'VLANs created. Customers will need to be migrated '
            'to their respective VLANs. This work should be planned '
            'during a low-traffic maintenance window.',
        warningNote: 'VLAN segmentation is a significant configuration '
            'change. Coordinate with your network manager before '
            'performing this step.',
        isCritical: true,
      ),

      TroubleshootStep(
        title:       'Verify Customer Connectivity',
        instruction: 'After all changes are complete, verify that '
            'customers are connecting and getting correct IP addresses. '
            'Ping a sample of customer ONUs and check that internet '
            'speeds are back to normal on the affected PON ports.',
        command:     'ping onu-ip 192.168.100.10 count 10',
        expectedResult: 'All pinged ONUs should respond with low latency '
            'below 5ms. Customers should now report normal internet '
            'speeds. Close the alert once confirmed.',
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Device Offline
  // ─────────────────────────────────────────────────────────────────────────
  static const TroubleshootScenario _deviceOffline = TroubleshootScenario(
    id:        'device_offline',
    title:     'Device Unreachable',
    alertType: 'device_offline',
    description: 'The device is not responding to ICMP ping requests. '
        'This could be a power issue, network issue, or hardware fault.',
    resolution: 'The device is back online and responding to pings. '
        'Monitor for the next 15 minutes to confirm stability.',
    steps: [
      TroubleshootStep(
        title:       'Check Physical Power',
        instruction: 'Physically verify that the device has power. '
            'Check that the power LED is on and the device '
            'is not showing any fault indicators.',
        expectedResult: 'Power LED is solid green. No alarm LEDs active.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Check Upstream Link',
        instruction: 'Verify that the upstream network connection '
            'is active. Check the link LED on the port connecting '
            'this device to the rest of the network.',
        expectedResult: 'Link LED is solid or blinking, indicating '
            'an active network connection.',
      ),
      TroubleshootStep(
        title:       'Ping from Adjacent Device',
        instruction: 'From another device on the same network segment, '
            'attempt to ping this device\'s IP address to rule out '
            'a routing issue.',
        command:     'ping 192.168.1.20 count 10',
        expectedResult: 'If pings succeed from the adjacent device but '
            'not from the monitoring server, the issue is a routing '
            'or firewall rule — not a hardware fault.',
      ),
      TroubleshootStep(
        title:       'Restart the Device',
        instruction: 'If all above steps show no issue but the device '
            'is still unreachable, perform a controlled restart. '
            'Use the management console if available before doing '
            'a physical power cycle.',
        command:     'reboot',
        expectedResult: 'Device restarts within 2 to 3 minutes and '
            'begins responding to pings.',
        warningNote: 'A power cycle will disconnect all customers '
            'served by this device. Inform NOC before proceeding.',
        isCritical: true,
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // High Latency
  // ─────────────────────────────────────────────────────────────────────────
  static const TroubleshootScenario _highLatency = TroubleshootScenario(
    id:        'high_latency',
    title:     'High Latency',
    alertType: 'high_latency',
    description: 'Round-trip latency to this device is consistently above '
        'the 200ms threshold. This causes slow response times for '
        'customers and indicates network congestion or a routing issue.',
    resolution: 'Latency has returned to normal levels below 50ms. '
        'The cause was identified and addressed.',
    steps: [
      TroubleshootStep(
        title:       'Check Bandwidth Utilisation',
        instruction: 'Check the interface utilisation on this device. '
            'High latency is often caused by a link running at or '
            'near 100% capacity.',
        command:     'show interface bandwidth-utilisation',
        expectedResult: 'Utilisation should be below 80%. If above 90%, '
            'the link is saturated and causing queuing delays.',
      ),
      TroubleshootStep(
        title:       'Check for Routing Loops',
        instruction: 'Run a traceroute from the monitoring server to '
            'this device. Look for packets bouncing between the same '
            'two hops repeatedly.',
        command:     'traceroute 192.168.1.20',
        expectedResult: 'A clean traceroute should show a short, direct '
            'path with each hop increasing in latency.',
      ),
      TroubleshootStep(
        title:       'Apply Traffic Shaping',
        instruction: 'If a specific customer or service is consuming '
            'disproportionate bandwidth, apply traffic shaping or '
            'QoS policies to prioritise critical traffic.',
        command:     'ip access-list extended THROTTLE\npermit ip any any dscp default',
        expectedResult: 'Latency drops as bandwidth-hungry traffic is '
            'deprioritised and network queues clear.',
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Packet Loss
  // ─────────────────────────────────────────────────────────────────────────
  static const TroubleshootScenario _packetLoss = TroubleshootScenario(
    id:        'packet_loss',
    title:     'Packet Loss',
    alertType: 'packet_loss',
    description: 'The device is dropping packets above the 5% threshold. '
        'Customers will experience slow speeds, buffering, and '
        'VoIP call quality issues.',
    resolution: 'Packet loss is back within acceptable levels below 1%. '
        'Customer connectivity is restored to normal.',
    steps: [
      TroubleshootStep(
        title:       'Check Interface Error Counters',
        instruction: 'Check the error counters on all interfaces. '
            'High CRC errors indicate a faulty cable or SFP module. '
            'High input errors indicate a duplex mismatch.',
        command:     'show interface errors',
        expectedResult: 'Error counters should be at zero or very low. '
            'Any counter above 100 per minute is a serious problem.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Check Optical Power Levels',
        instruction: 'For fibre connections, check the optical receive '
            'and transmit power levels on the relevant SFP or PON port.',
        command:     'show optical-transceiver detail',
        expectedResult: 'Receive power should be within the acceptable '
            'range specified for your SFP module — typically '
            'between -3 dBm and -20 dBm.',
        warningNote: 'Power below -25 dBm indicates a dirty connector, '
            'a bend in the fibre, or a failing SFP.',
      ),
      TroubleshootStep(
        title:       'Replace Suspect SFP or Cable',
        instruction: 'If optical levels are outside acceptable range '
            'or CRC errors are high, replace the SFP module and '
            'clean or replace the fibre patch cable.',
        expectedResult: 'After replacing, error counters should drop '
            'to zero and optical levels should normalise.',
        warningNote: 'Power down the port before replacing an SFP. '
            'Never look directly into a fibre connector.',
        isCritical: true,
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // High CPU
  // ─────────────────────────────────────────────────────────────────────────
  static const TroubleshootScenario _highCpu = TroubleshootScenario(
    id:        'high_cpu',
    title:     'High CPU Usage',
    alertType: 'high_cpu',
    description: 'The device CPU is running above 80% utilisation. '
        'This can cause slow management response, routing instability, '
        'and in severe cases device crashes.',
    resolution: 'CPU usage has dropped to normal levels below 50%. '
        'The device is stable and managing traffic normally.',
    steps: [
      TroubleshootStep(
        title:       'Identify CPU-Intensive Processes',
        instruction: 'Check which processes are consuming the most CPU '
            'cycles. Look for routing protocol recalculations, '
            'spanning tree changes, or management plane storms.',
        command:     'show processes cpu sorted',
        expectedResult: 'A single process should not be consuming more '
            'than 40% CPU. If one is, note its name for the next step.',
      ),
      TroubleshootStep(
        title:       'Check for Broadcast Storms',
        instruction: 'A broadcast storm — where a network loop causes '
            'packets to multiply endlessly — is a common cause of '
            'sudden CPU spikes. Check interface input rates.',
        command:     'show interface counters rate',
        expectedResult: 'Input packet rates should be steady and within '
            'normal range. A sudden spike of millions of packets per '
            'second indicates a broadcast storm.',
        isCritical: true,
      ),
      TroubleshootStep(
        title:       'Disable Affected Port to Break Loop',
        instruction: 'If a broadcast storm is confirmed, identify the '
            'port causing the loop and shut it down immediately. '
            'Verify that spanning tree is enabled and working.',
        command:     'interface eth 0/1\n shutdown',
        expectedResult: 'CPU drops immediately after the port is shut. '
            'Investigate the connected device before bringing the '
            'port back up.',
        warningNote: 'Shutting a port disconnects customers on that '
            'segment. Confirm with NOC before proceeding.',
        isCritical: true,
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // High Memory
  // ─────────────────────────────────────────────────────────────────────────
   static const TroubleshootScenario _highMemory = TroubleshootScenario(
    id:        'high_memory',
    title:     'High Memory Usage',
    alertType: 'high_memory',
    description: 'Device memory usage is above 85%. This can cause '
        'the device to fail to process new connections and in '
        'extreme cases crash and reboot.',
    resolution: 'Memory usage is back within safe levels below 70%. '
        'The device is operating normally.',
    steps: [
      TroubleshootStep(
        title:       'Check Memory Consumers',
        instruction: 'Identify which processes or tables are consuming '
            'the most memory. Common causes are large routing tables, '
            'MAC address tables, ARP tables, or memory leaks in '
            'specific processes.',
        command:     'show memory statistics',
        expectedResult: 'Total, used, and free memory displayed. '
            'Identify which memory pools are largest.',
      ),
      TroubleshootStep(
        title:       'Clear Unused Table Entries',
        instruction: 'Clear ARP cache, MAC address table, and any '
            'other aged-out entries that are consuming memory '
            'unnecessarily.',
        command:     'clear arp-cache\nclear mac-address-table dynamic',
        expectedResult: 'Memory usage should drop by 5 to 15% after '
            'clearing caches. Active entries will be re-learned.',
      ),
      TroubleshootStep(
        title:       'Schedule Controlled Restart if Critical',
        instruction: 'If memory is above 95% and dropping entries '
            'has not helped, schedule a controlled restart during '
            'the next maintenance window. Monitor closely until then.',
        command:     'reload at 02:00',
        expectedResult: 'Device restarts at the scheduled time, '
            'clearing all memory and starting fresh.',
        warningNote: 'A restart disconnects all customers. Always '
            'schedule during the lowest traffic window.',
        isCritical: true,
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Interface Errors
  // ─────────────────────────────────────────────────────────────────────────
  static const TroubleshootScenario _interfaceErrors = TroubleshootScenario(
    id:        'interface_error',
    title:     'Interface Errors',
    alertType: 'interface_error',
    description: 'High error counts detected on one or more interfaces. '
        'This indicates physical layer problems — dirty fibre, '
        'faulty cables, failing hardware, or duplex mismatches.',
    resolution: 'Interface error counters have reset to zero and '
        'remain clean after monitoring for 30 minutes.',
    steps: [
      TroubleshootStep(
        title:       'Identify Affected Interfaces',
        instruction: 'Check all interface error counters to identify '
            'which specific interfaces have errors.',
        command:     'show interface errors',
        expectedResult: 'Most interfaces should show zero errors. '
            'Any interface with errors above 10 per minute '
            'needs immediate attention.',
      ),
      TroubleshootStep(
        title:       'Clean Fibre Connectors',
        instruction: 'For fibre interfaces, clean the SFP and fibre '
            'patch cable connectors using a fibre cleaning tool. '
            'Dust and oil from fingerprints are the most common '
            'cause of CRC errors.',
        expectedResult: 'After cleaning, reseat the fibre and '
            'monitor error counters. They should drop to zero '
            'within 1 minute.',
        warningNote: 'Never touch the end face of a fibre connector '
            'with your fingers. Always use proper cleaning tools.',
      ),
      TroubleshootStep(
        title:       'Replace Faulty SFP Module',
        instruction: 'If cleaning does not resolve the errors, '
            'replace the SFP module with a known-good spare.',
        expectedResult: 'New SFP installed. Error counters should '
            'immediately drop to zero.',
        isCritical: true,
      ),
    ],
  );

  // ─────────────────────────────────────────────────────────────────────────
  // Generic Connectivity
  // ─────────────────────────────────────────────────────────────────────────
  static const TroubleshootScenario _genericConnectivity =
      TroubleshootScenario(
    id:        'generic',
    title:     'Connectivity Issue',
    alertType: 'generic',
    description: 'A network connectivity issue has been detected. '
        'Follow these general steps to diagnose and resolve.',
    resolution: 'The connectivity issue has been identified and resolved.',
    steps: [
      TroubleshootStep(
        title:       'Verify Physical Connections',
        instruction: 'Check all cables, SFPs, and physical connections '
            'on the affected device.',
        expectedResult: 'All LEDs are green and no fault indicators '
            'are active.',
      ),
      TroubleshootStep(
        title:       'Run Ping Test',
        instruction: 'Run a ping test from the monitoring server '
            'to the device to check basic reachability.',
        command:     'ping [device-ip] count 20',
        expectedResult: 'Pings succeed with low latency.',
      ),
      TroubleshootStep(
        title:       'Check Device Logs',
        instruction: 'Review the device system logs for any error '
            'messages around the time the alert was triggered.',
        command:     'show logging last 100',
        expectedResult: 'Logs may reveal the root cause — interface '
            'flaps, protocol restarts, or hardware errors.',
      ),
    ],
  );
}