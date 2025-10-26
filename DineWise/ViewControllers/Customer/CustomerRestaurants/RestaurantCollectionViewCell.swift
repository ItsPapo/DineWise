//
//  RestaurantCollectionViewCell.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-04-08.
//

import UIKit

class RestaurantCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet var featuredImage: UIImageView!
    @IBOutlet var lblRestaurantName : UILabel!
    
    
    override init(frame: CGRect){
        super.init(frame: frame)
        self.commonInit()
    }
    
    required init?(coder aDecoder: NSCoder){
        super.init(coder: aDecoder)
    }
    
    private func commonInit(){
        
        self.layoutIfNeeded()
        self.layoutSubviews()
        self.setNeedsDisplay()
    }
    
    // used to highlight cell
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
     
        if (self.isFocused){
            self.featuredImage.adjustsImageSizeForAccessibilityContentSizeCategory = true
        }
        else{
            self.featuredImage.adjustsImageSizeForAccessibilityContentSizeCategory = false
        }
    }
    
    override func layoutSubviews(){
        super.layoutSubviews()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
    }
}
