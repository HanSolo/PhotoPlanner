//
//  CameraView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 29.04.26.
//

import Foundation
import SwiftUI
import SwiftData


struct LensView: View {
    @Environment(\.colorScheme)          private var colorScheme
    @Environment(\.modelContext)         private var context
    @Environment(\.dismiss)              private var dismiss
    @Environment(PhotoPlannerModel.self) private var model
    
    @State                               private var addLensViewVisible : Bool = false
    
    let lenses : [Lens]

        
    var body: some View {
        NavigationStack {
            VStack {
                HStack(spacing: 10) {
                    Button("Add Lens") {
                        self.addLensViewVisible = true
                    }
                    
                    Spacer()
                    
                    Button("Close") {
                        dismiss()
                    }
                }
                .buttonStyle(.glass)
                .padding()
            }
            
            List {
                ForEach(lenses, id: \.id) { lens in
                    NavigationLink(value: lens) {
                        HStack(spacing: .some(15)) {
                            Button {
                            } label: {
                                Image(systemName: lens.id == self.model.lens.id ? "checkmark.circle.fill" : "checkmark.circle")
                            }
                            .highPriorityGesture(TapGesture().onEnded {
                                self.model.lens = lens
                                dismiss()
                            })
                            VStack(alignment: .leading) {
                                Text(lens.name)
                                    .font(Constants.REGULAR_FONT_16)
                                if lens.isPrime {
                                    Text("\(String(format: "%.0f", lens.minFocalLength)) mm")
                                        .font(Constants.REGULAR_FONT_14)
                                } else {
                                    Text("\(String(format: "%.0f", lens.minFocalLength)) - \(String(format: "%.0f", lens.maxFocalLength)) mm")
                                        .font(Constants.REGULAR_FONT_14)
                                }
                                Text("f/\(String(format: "%.1f", lens.minAperture)) - f/\(String(format: "%.1f", lens.maxAperture))")
                                    .font(Constants.REGULAR_FONT_14)
                            }
                        }
                    }
                    .listRowBackground(self.colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.9, green: 0.9, blue: 0.9))
                }
                .onDelete(perform: deleteLens)
            }
            .scrollContentBackground(.hidden)
            .background(self.colorScheme == .dark ? .black : .white)
            .navigationDestination(for: Lens.self) { lens in
                LensDetailView(lens: lens)
            }
            .foregroundStyle(self.colorScheme == .dark ? .white : .black)
        }
        .sheet(isPresented: self.$addLensViewVisible) {
            AddLensView()
        }
    }
    
    private func deleteLens(indexSet: IndexSet) {
        indexSet.forEach { index in
            let lens = lenses[index]
            context.delete(lens)
            do {
                try context.save()
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}
