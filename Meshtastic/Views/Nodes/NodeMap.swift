//
//  NodeMap.swift
//  MeshtasticApple
//
//  Created by Garth Vander Houwen on 8/7/21.
//

import SwiftUI
import MapKit
import CoreLocation
import CoreData

struct NodeMap: View {

	@Environment(\.managedObjectContext) var context
	@EnvironmentObject var bleManager: BLEManager

	@State var meshMapType: Int = UserDefaults.mapType
	@State var enableMapRecentering: Bool = UserDefaults.enableMapRecentering
	@State var enableMapRouteLines: Bool = UserDefaults.enableMapRouteLines
	@State var enableMapNodeHistoryPins: Bool = UserDefaults.enableMapNodeHistoryPins
	@State var enableOfflineMaps: Bool = UserDefaults.enableOfflineMaps
	@State var mapTileServer: String = UserDefaults.mapTileServer
	@State var mapRect: MKMapRect = MKMapRect()

	@FetchRequest(sortDescriptors: [NSSortDescriptor(key: "time", ascending: true)],
				  predicate: NSPredicate(format: "time >= %@ && nodePosition != nil", Calendar.current.startOfDay(for: Date()) as NSDate), animation: .none)
	private var positions: FetchedResults<PositionEntity>

	@FetchRequest(sortDescriptors: [NSSortDescriptor(key: "name", ascending: false)],
				  predicate: NSPredicate(
					format: "expire == nil || expire >= %@", Date() as NSDate
				  ), animation: .none)
	private var waypoints: FetchedResults<WaypointEntity>

	
	@State var mapType: MKMapType = .standard
	@State var selectedTracking: UserTrackingModes = .none
	@State var selectedTileServer: MapTileServerLinks = .wikimedia
	@State var isPresentingInfoSheet: Bool = false
	
	@State var waypointCoordinate: WaypointCoordinate?
	@State private var customMapOverlay: MapViewSwiftUI.CustomMapOverlay? = MapViewSwiftUI.CustomMapOverlay(
			mapName: "offlinemap",
			tileType: "png",
			canReplaceMapContent: true
		)

	var body: some View {

		NavigationStack {
			ZStack {

				MapViewSwiftUI(
						onLongPress: { coord in
						waypointCoordinate = WaypointCoordinate(id: .init(), coordinate: coord, waypointId: 0)
					}, onWaypointEdit: { wpId in
						if wpId > 0 {
							waypointCoordinate = WaypointCoordinate(id: .init(), coordinate: nil, waypointId: Int64(wpId))
						}
					},
				   visibleMapRect: $mapRect,
				   positions: Array(positions),
				   waypoints: Array(waypoints),
				   mapViewType: mapType,
				   userTrackingMode: selectedTracking.MKUserTrackingModeValue(),
				   showNodeHistory: enableMapNodeHistoryPins,
				   showRouteLines: enableMapRouteLines,
				   customMapOverlay: self.customMapOverlay
				)
				VStack(alignment: .trailing) {
					
					HStack(alignment: .top) {
						Spacer()
						MapButtons(tracking: $selectedTracking, isPresentingInfoSheet: $isPresentingInfoSheet)
							.padding(.trailing, 8)
							.padding(.top, 16)
					}
					
					Spacer()
					
				}
			}
			.ignoresSafeArea(.all, edges: [.top, .leading, .trailing])
			.frame(maxHeight: .infinity)
			.sheet(item: $waypointCoordinate, content: { wpc in
							WaypointFormView(coordinate: wpc)
								.presentationDetents([.medium, .large])
								.presentationDragIndicator(.automatic)
			})
			.sheet(isPresented: $isPresentingInfoSheet) {
				VStack {
					Form {
						Section(header: Text("Map Options")) {
							Picker("Map Type", selection: $mapType) {
								ForEach(MeshMapTypes.allCases) { map in
									Text(map.description).tag(map.MKMapTypeValue())
								}
							}
							.pickerStyle(DefaultPickerStyle())
							.onChange(of: (mapType)) { newMapType in
								UserDefaults.mapType = Int(newMapType.rawValue)
							}
							
							Toggle(isOn: $enableMapRecentering) {
								
								Label("map.recentering", systemImage: "camera.metering.center.weighted")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.onTapGesture {
								self.enableMapRecentering.toggle()
								UserDefaults.enableMapRecentering = self.enableMapRecentering
							}
							
							Toggle(isOn: $enableMapNodeHistoryPins) {
								
								Label("Show Node History", systemImage: "building.columns.fill")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.onTapGesture {
								self.enableMapNodeHistoryPins.toggle()
								UserDefaults.enableMapNodeHistoryPins = self.enableMapNodeHistoryPins
							}
							
							Toggle(isOn: $enableMapRouteLines) {
								
								Label("Show Route Lines", systemImage: "road.lanes")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.onTapGesture {
								self.enableMapRouteLines.toggle()
								UserDefaults.enableMapRouteLines = self.enableMapRouteLines
							}
						}
						Section(header: Text("Offline Maps")) {
							Toggle(isOn: $enableOfflineMaps) {
								Text("Enable Offline Maps")
							}
							.toggleStyle(SwitchToggleStyle(tint: .accentColor))
							.onTapGesture {
								self.enableOfflineMaps.toggle()
								UserDefaults.enableOfflineMaps = self.enableOfflineMaps
							}
							Text("If you have shared a MBTiles file with meshtastic it will be loaded.")
								.font(.caption)
								.foregroundColor(.gray)
							
							if UserDefaults.enableOfflineMaps {
								VStack {
//									Picker("Tile Servers", selection: $selectedTileServer) {
//										ForEach(MapTileServerLinks.allCases) { ts in
//											Text(ts.description)
//												.tag(ts.id)
//										}
//									}
//									.pickerStyle(.menu)
//									.onChange(of: (selectedTileServer)) { newTileServer in
//									
//										mapTileServer = selectedTileServer.tileUrl
//									}
									
									TilesDownloadView(boundingBox: mapRect, name: "All tiles")
									HStack {
										Label("Tile Server", systemImage: "square.grid.3x2")
										TextField(
											"Tile Server",
											text: $mapTileServer,
											axis: .vertical
										)
										.foregroundColor(.gray)
										.font(.caption)
										.onChange(of: (mapTileServer)) { newMapTileServer in
											UserDefaults.mapTileServer = newMapTileServer
										}
									}
								}
								.keyboardType(.asciiCapable)
								.disableAutocorrection(true)
							}
						}
					}
					#if targetEnvironment(macCatalyst)
					Button {
						isPresentingInfoSheet = false
					} label: {
						Label("close", systemImage: "xmark")
					}
					.buttonStyle(.bordered)
					.buttonBorderShape(.capsule)
					.controlSize(.large)
					.padding(.bottom)
					#endif
				}
				.presentationDetents([.medium, .large])
				.presentationDragIndicator(.visible)
			}
		}
		.navigationBarItems(leading:
								MeshtasticLogo(), trailing:
								ZStack {
			ConnectedDevice(
				bluetoothOn: bleManager.isSwitchedOn,
				deviceConnected: bleManager.connectedPeripheral != nil,
				name: (bleManager.connectedPeripheral != nil) ? bleManager.connectedPeripheral.shortName :
					"????")
		})
		.onAppear(perform: {
			UIApplication.shared.isIdleTimerDisabled = true
			self.bleManager.context = context
			mapType = MeshMapTypes(rawValue: meshMapType)?.MKMapTypeValue() ?? .standard
		
		})
		.onDisappear(perform: {
			UIApplication.shared.isIdleTimerDisabled = false
		})
	}
}
