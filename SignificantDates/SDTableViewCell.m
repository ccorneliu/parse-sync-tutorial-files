//
//  SDTableViewCell.m
//  SignificantDates
//
//  Created by Chris Wagner on 5/25/12.
//

#import "SDTableViewCell.h"

@implementation SDTableViewCell
@synthesize imageView;
@synthesize nameLabel;
@synthesize dateLabel;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Initialization code
    }
    return self;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
