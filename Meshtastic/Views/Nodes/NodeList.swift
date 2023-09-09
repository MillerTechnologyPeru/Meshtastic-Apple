//
//  NodeList.swift
//  Meshtastic
//
//  Copyright(c) Garth Vander Houwen 8/7/21.
//

// Abstract:
//  A view showing a list of devices that have been seen on the mesh network from the perspective of the connected device.

import SwiftUI
import CoreLocation

struct NodeList: View {
	
	@State private var searchText = ""
	var nodesQuery: Binding<String> {
		 Binding {
			 searchText
		 } set: { newValue in
			 searchText = newValue
			 nodes.nsPredicate = newValue.isEmpty ? nil : NSPredicate(format: "user.longName CONTAINS[c] %@ OR user.shortName CONTAINS[c] %@", newValue, newValue)
		 }
	 }

	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager

	@FetchRequest(
		sortDescriptors: [NSSortDescriptor(key: "lastHeard", ascending: false)],
		animation: .default)

	private var nodes: FetchedResults<NodeInfoEntity>

	@State private var selection: NodeInfoEntity? // Nothing selected by default.

	var body: some View {

		NavigationSplitView {
			let connectedNodeNum = Int(bleManager.connectedPeripheral != nil ? bleManager.connectedPeripheral?.num ?? 0 : 0)
			let connectedNode = nodes.first(where: { $0.num == connectedNodeNum })
			List(nodes, id: \.self, selection: $selection) { node in
				if nodes.count == 0 {
					Text("no.nodes").font(.title)
				} else {
					NavigationLink(value: node) {
						let connected: Bool = (bleManager.connectedPeripheral != nil && bleManager.connectedPeripheral?.num ?? -1 == node.num)
						LazyVStack(alignment: .leading) {
							HStack {
								VStack(alignment: .leading) {
									CircleText(text: node.user?.shortName ?? "?", color: Color(UIColor(hex: UInt32(node.num))), circleSize: 65)
										.padding(.trailing, 5)
									let deviceMetrics = node.telemetries?.filtered(using: NSPredicate(format: "metricsType == 0"))
									if deviceMetrics?.count ?? 0 >= 1 {
										let mostRecent = deviceMetrics?.lastObject as? TelemetryEntity
										BatteryLevelCompact(batteryLevel: mostRecent?.batteryLevel, font: .caption2, iconFont: .callout, color: .accentColor)
									}
								}
								VStack(alignment: .leading) {
									Text(node.user?.longName ?? "unknown".localized)
										.fontWeight(.medium)
										.font(.callout)
									if connected {
										HStack(alignment: .bottom) {
											Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
												.font(.footnote)
												.symbolRenderingMode(.hierarchical)
												.foregroundColor(.green)
											Text("connected").font(.caption)
										}
									}
									HStack(alignment: .bottom) {
										Image(systemName: node.isOnline ? "checkmark.circle.fill" : "moon.circle.fill")
											.font(.footnote)
											.symbolRenderingMode(.hierarchical)
											.foregroundColor(node.isOnline ? .green : .orange)
										LastHeardText(lastHeard: node.lastHeard)
											.font(.caption)
									}
									if node.positions?.count ?? 0 > 0 && (bleManager.connectedPeripheral != nil && bleManager.connectedPeripheral?.num ?? -1 != node.num) {
										HStack(alignment: .bottom) {
											let lastPostion = node.positions!.reversed()[0] as! PositionEntity
											let myCoord = CLLocation(latitude: LocationHelper.currentLocation.latitude, longitude: LocationHelper.currentLocation.longitude)
											if lastPostion.nodeCoordinate != nil && myCoord.coordinate.longitude != LocationHelper.DefaultLocation.longitude && myCoord.coordinate.latitude != LocationHelper.DefaultLocation.latitude {
												let nodeCoord = CLLocation(latitude: lastPostion.nodeCoordinate!.latitude, longitude: lastPostion.nodeCoordinate!.longitude)
												let metersAway = nodeCoord.distance(from: myCoord)
												Image(systemName: "lines.measurement.horizontal")
													.font(.footnote)
													.symbolRenderingMode(.hierarchical)
												DistanceText(meters: metersAway).font(.caption)
											}
										}
									}
									if node.channel > 0 {
										HStack(alignment: .bottom) {
											Image(systemName: "fibrechannel")
												.font(.footnote)
												.symbolRenderingMode(.hierarchical)
											Text("Channel: \(node.channel)")
												.font(.footnote)
										}
									}
									if !connected {
										HStack(alignment: .bottom) {										let preset = ModemPresets(rawValue: Int(connectedNode?.loRaConfig?.modemPreset ?? 0))
											LoRaSignalStrengthMeter(snr: node.snr, rssi: node.rssi, preset: preset ?? ModemPresets.longFast, compact: true)
										}
									}
								}
								.frame(maxWidth: .infinity, alignment: .leading)
							}
						}
					}
					.padding([.top, .bottom])
				}
			 }
			.listStyle(.plain)
			.navigationSplitViewColumnWidth(300)
			.navigationTitle(String.localizedStringWithFormat("nodes %@".localized, String(nodes.count)))
			.navigationBarItems(leading:
				MeshtasticLogo()
			)
			.onAppear {
				if self.bleManager.context == nil {
					self.bleManager.context = context
				}
			}
	   } detail: {
		   if let node = selection {
			   NodeDetail(node: node)
		   } else {
			   Text("select.node")
		   }
	   }
	   .searchable(text: nodesQuery, prompt: "Find a node")
	}
}
