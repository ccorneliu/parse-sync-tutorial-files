//
//  SDDateDetailViewController.h
//  SignificantDates
//
//  Created by Chris Wagner on 6/1/12.
//

#import <UIKit/UIKit.h>

@interface SDDateDetailViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) NSManagedObjectID *managedObjectId;
@property (strong, nonatomic) IBOutlet UIImageView *imageView;
@property (strong, nonatomic) IBOutlet UITableView *detailTableView;

@end
