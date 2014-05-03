//
//  SDTableViewCell.h
//  SignificantDates
//
//  Created by Chris Wagner on 5/25/12.
//

#import <UIKit/UIKit.h>

@interface SDTableViewCell : UITableViewCell

@property (nonatomic, strong) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) IBOutlet UILabel *nameLabel;
@property (nonatomic, strong) IBOutlet UILabel *dateLabel;

@end
