//
//  SDAddDateViewController.h
//  SignificantDates
//
//  Created by Chris Wagner on 6/5/12.
//

#import <UIKit/UIKit.h>
#import "SDSyncEngine.h"

@interface SDAddDateViewController : UIViewController

@property (strong, nonatomic) IBOutlet UITextField *nameTextField;
@property (strong, nonatomic) IBOutlet UITextField *option1TextField;
@property (strong, nonatomic) IBOutlet UITextField *option2TextField;
@property (strong, nonatomic) IBOutlet UIButton *setDateButton;
@property (strong, nonatomic) IBOutlet UIDatePicker *datePicker;
@property (strong, nonatomic) NSString *entityName;

@property (copy, nonatomic) void (^addDateCompletionBlock)(void);

- (IBAction)setDateButtonTouched:(id)sender;
- (IBAction)saveButtonTouched:(id)sender;

@end
