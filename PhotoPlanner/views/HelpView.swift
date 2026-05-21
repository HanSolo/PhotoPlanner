//
//  HelpView.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 06.05.26.
//

import SwiftUI

struct HelpView: View {
    private let font : Font = Font.system(size: 12)
    
    var body: some View {
        ZStack (alignment: .topLeading) {
            Color.black.opacity(0.5)
            
            VStack(alignment: .leading, spacing: 10) {
                EmptyView()
                
                EmptyView()
                
                HStack {
                    Text("Select/Add Camera")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Text("Place Camera")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 50))
                }
                .padding(EdgeInsets(top: 90, leading: 0, bottom: 0, trailing: 0))
                
                HStack {
                    Text("Select/Add Lens")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Text("Place Subject")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 50))
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                
                HStack {
                    Text("Show DoF")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Text("Center on camera location")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 50))
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                
                HStack {
                    Text("Rotate camera")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Text("Save a new photo shoot")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 50))
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                
                HStack {
                    Text("Date for calculations")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Text("Restore a photo shoot")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 50))
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                
                HStack {
                    Text("Sunrise/sunset times")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                
                HStack {
                    Text("Sunrise/sunset quality for today")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                
                HStack {
                    Text("Moon phase")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Text("AR view")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 50))
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                                                                                        
                HStack {
                    Text("Milkyway core")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Text("B&W long exposure")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 50))
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                                                
                HStack {
                    Text("Elevation")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.leading)
                        .padding(EdgeInsets(top: 0, leading: 50, bottom: 0, trailing: 0))
                    
                    Spacer()
                    
                    Text("Setup Teleconverter(s)")
                        .font(font)
                        .foregroundStyle(Color.white)
                        .multilineTextAlignment(.trailing)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 50))
                }
                .padding(EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 0))
                
                Spacer()
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
        }
    }
}

#Preview {
    HelpView()
}
