//
//  UIImage+grayscale.swift
//  PhotoPlanner
//
//  Created by Gerrit Grunwald on 28.08.26.
//

import Foundation
import UIKit


extension UIImage {
    var noir: UIImage {
        let context        : CIContext = CIContext(options: nil)
        let currentFilter  : CIFilter  = CIFilter(name: "CIPhotoEffectNoir")!
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        let output         : CIImage   = currentFilter.outputImage!
        let cgImage        : CGImage   = context.createCGImage(output, from: output.extent)!
        let processedImage : UIImage   = UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)

        return processedImage
    }
    
    var tonal: UIImage {
        let context        : CIContext = CIContext(options: nil)
        let currentFilter  : CIFilter  = CIFilter(name: "CIPhotoEffectTonal")!
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        let output         : CIImage   = currentFilter.outputImage!
        let cgImage        : CGImage   = context.createCGImage(output, from: output.extent)!
        let processedImage : UIImage   = UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)

        return processedImage
    }
    
    var mono: UIImage {
        let context        : CIContext = CIContext(options: nil)
        let currentFilter  : CIFilter  = CIFilter(name: "CIPhotoEffectMono")!
        currentFilter.setValue(CIImage(image: self), forKey: kCIInputImageKey)
        let output         : CIImage   = currentFilter.outputImage!
        let cgImage        : CGImage   = context.createCGImage(output, from: output.extent)!
        let processedImage : UIImage   = UIImage(cgImage: cgImage, scale: scale, orientation: imageOrientation)

        return processedImage
    }
}
