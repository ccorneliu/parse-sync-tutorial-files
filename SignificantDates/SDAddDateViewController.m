//
//  SDAddDateViewController.m
//  SignificantDates
//
//  Created by Chris Wagner on 6/5/12.

//

#import "SDAddDateViewController.h"
#import "SDCoreDataController.h"

@interface SDAddDateViewController ()

@property CGPoint originalCenter;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong) NSManagedObject *date;

@end

@implementation SDAddDateViewController

@synthesize nameTextField;
@synthesize option1TextField;
@synthesize option2TextField;
@synthesize setDateButton;
@synthesize datePicker;
@synthesize entityName;

@synthesize addDateCompletionBlock;

@synthesize originalCenter;
@synthesize managedObjectContext;
@synthesize date;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.managedObjectContext = [[SDCoreDataController sharedInstance] newManagedObjectContext];
    self.date = [NSEntityDescription insertNewObjectForEntityForName:self.entityName inManagedObjectContext:self.managedObjectContext];
    self.datePicker.date = [NSDate date];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.originalCenter = self.view.center;
}

- (void)viewDidUnload {
    [self setNameTextField:nil];
    [self setOption1TextField:nil];
    [self setOption2TextField:nil];
    [self setSetDateButton:nil];
    [self setDatePicker:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (IBAction)setDateButtonTouched:(id)sender {
    [self.nameTextField resignFirstResponder];
    [self.option1TextField resignFirstResponder];
    [self.option2TextField resignFirstResponder];
    
    if (self.datePicker.isHidden) {
        [self.datePicker setHidden:NO];
        [UIView animateWithDuration:0.3 animations:^{
            [self.view setCenter:CGPointMake(self.originalCenter.x, self.originalCenter.y-30)]; 
        }];
    } else {
        [UIView animateWithDuration:0.3 animations:^{
            [self.view setCenter:self.originalCenter];
        } completion:^(BOOL finished) {
            [self.datePicker setHidden:YES];
        }];
    }
}

- (IBAction)saveButtonTouched:(id)sender {
    if (![self.nameTextField.text isEqualToString:@""] && self.datePicker.date) {
        [self.date setValue:self.nameTextField.text forKey:@"name"];
        [self.date setValue:[self dateSetToMidnightUsingDate:self.datePicker.date] forKey:@"date"];
        // Set syncStatus flag to SDObjectCreated
        [self.date setValue:[NSNumber numberWithInt:SDObjectCreated] forKey:@"syncStatus"];
        
        if ([self.entityName isEqualToString:@"Holiday"]) {
            [self.date setValue:self.option1TextField.text forKey:@"details"];
            [self.date setValue:self.option2TextField.text forKey:@"wikipediaLink"];
        } else if ([self.entityName isEqualToString:@"Birthday"]) {
            [self.date setValue:self.option1TextField.text forKey:@"giftIdeas"];
            [self.date setValue:self.option2TextField.text forKey:@"facebook"];
        }
        [self.managedObjectContext performBlockAndWait:^{
            NSError *error = nil;
            BOOL saved = [self.managedObjectContext save:&error]; 
            if (!saved) {
                // do some real error handling
                NSLog(@"Could not save Date due to %@", error);
            }
            [[SDCoreDataController sharedInstance] saveMasterContext];
        }];
        
        [self.navigationController popViewControllerAnimated:YES];
        addDateCompletionBlock();
        
    } else {
        UIAlertView *cannotSaveAlert = [[UIAlertView alloc] initWithTitle:@"Uh oh..." message:@"You must at least set a name and date" delegate:nil cancelButtonTitle:@"Duh" otherButtonTitles:nil];
        [cannotSaveAlert show];
    }
}

- (NSDate *)dateSetToMidnightUsingDate:(NSDate *)aDate {
    NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    NSDateComponents *components = [gregorian components:NSUIntegerMax fromDate:aDate];
    [components setHour:0];
    [components setMinute:0];
    [components setSecond:0];
    
    return [gregorian dateFromComponents: components];
}

@end
