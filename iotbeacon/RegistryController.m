//
//  RegistryController.m
//  iotbeacon
//
//  Created by Vladimir on 13/01/16.
//  Copyright © 2016 BIS. All rights reserved.
//

#import "RegistryController.h"
#import "UserData.h"
#import "AFHTTPRequestOperationManager.h"

@implementation RegistryController
@synthesize emailTextField;
@synthesize occupationTextField;
@synthesize firstNameTextField;
@synthesize lastNameTextField;
@synthesize middleNameTextField;
@synthesize currentTextField;
@synthesize datePicker;
@synthesize user;
@synthesize scrollView;
@synthesize saveButton;
@synthesize messageView;
@synthesize messageLabel;
@synthesize activityIndicator;

#define kOFFSET_FOR_KEYBOARD 160.0
#define ADD_USER_SERVICE_URL @"http://uliyneron.no-ip.org/ibeacon/user.php"

CGFloat currentKeyboardHeight = 0.0f;

-(void)viewDidLoad {
    if (user != nil) {
        [firstNameTextField setText:user.firstName];
        [lastNameTextField setText:user.lastName];
        [middleNameTextField setText:user.middleName];
        [emailTextField setText:user.email];
        [occupationTextField setText:user.occupation];
        if (user.birthDate != nil) {
            [datePicker setDate:user.birthDate];
        }
    } else {
        self.user = [[UserData alloc] init];
    }
    [self.datePicker setValue:[UIColor colorWithRed:1.0f green:1.0f blue:1.0f alpha:1.0f] forKeyPath:@"textColor"];
    SEL selector = NSSelectorFromString(@"setHighlightsToday:");
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[UIDatePicker instanceMethodSignatureForSelector:selector]];
    BOOL no = NO;
    [invocation setSelector:selector];
    [invocation setArgument:&no atIndex:2];
    [invocation invokeWithTarget:self.datePicker];
    
    //[saveButton addTarget:self action:@selector(saveButtonClicked:) forControlEvents:UIControlEventTouchDown];
    //[saveButton addTarget:self action:@selector(saveButtonClicked) forControlEvents:UIControlEventTouchDown];
}

-(void)viewDidAppear:(BOOL)animated {
    [scrollView setContentSize:CGSizeMake(scrollView.frame.size.width, saveButton.frame.origin.y + saveButton.frame.size.height + 50)];
    //[scrollContentView setFrame:CGRectMake(0, 0, scrollView.frame.size.width, saveButton.frame.origin.y + saveButton.frame.size.height + 50)];
    
    //[saveButton setUserInteractionEnabled:YES];
    //[scrollView setExclusiveTouch:NO];
    //[scrollContentView setUserInteractionEnabled:YES];
    //[scrollContentView setExclusiveTouch:NO];
}

-(void)keyboardWillShow:(NSNotification*)notification {
    NSDictionary *info = [notification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    currentKeyboardHeight = kbSize.height;
    
    if ((currentTextField == emailTextField) || (currentTextField == occupationTextField)) {
        if (self.view.frame.origin.y >= 0) {
            [self setViewMovedUp:YES];
        }
    } else {
        if (self.view.frame.origin.y < 0) {
            [self setViewMovedUp:NO];
        }
    }
}

-(void)keyboardWillHide {
    if (self.view.frame.origin.y >= 0)
    {
        [self setViewMovedUp:YES];
    }
    else if (self.view.frame.origin.y < 0)
    {
        [self setViewMovedUp:NO];
    }
}

-(void)textFieldDidBeginEditing:(UITextField *)sender
{
    currentTextField = sender;
}

//method to move the view up/down whenever the keyboard is shown/dismissed
-(void)setViewMovedUp:(BOOL)movedUp
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3]; // if you want to slide up the view
    
    CGRect rect = self.view.frame;
    if (movedUp)
    {
        rect.origin.y -= currentKeyboardHeight;
        //rect.size.height += currentKeyboardHeight;
    }
    else
    {
        // revert back to the normal state.
        rect.origin.y += currentKeyboardHeight;
        //rect.size.height -= currentKeyboardHeight;
    }
    self.view.frame = rect;
    
    [UIView commitAnimations];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // unregister for keyboard notifications while not visible.
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == lastNameTextField) {
        [firstNameTextField becomeFirstResponder];
    } else if (textField == firstNameTextField) {
        [middleNameTextField becomeFirstResponder];
    } else if (textField == middleNameTextField) {
        [emailTextField becomeFirstResponder];
    } else if (textField == emailTextField) {
        [occupationTextField becomeFirstResponder];
    } else if (textField == occupationTextField) {
        [self.view endEditing:TRUE];
        [self saveButtonClicked:saveButton];
    }
    return YES;
}

- (IBAction)saveButtonClicked:(id)sender {
    if (firstNameTextField.text.length < 3) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Введите имя" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        return;
    } else if (lastNameTextField.text.length < 3) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Введите фамилию" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        return;
    } else if (middleNameTextField.text.length < 3) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Введите отчество" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        return;
    } else if ((emailTextField.text.length < 3) || ([emailTextField.text containsString:@"@"] == NO)) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:@"Введите email" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    user.lastName = lastNameTextField.text;
    user.firstName = firstNameTextField.text;
    user.middleName = middleNameTextField.text;
    user.email = emailTextField.text;
    user.occupation = occupationTextField.text;
    user.birthDate = datePicker.date;
    [self saveUserData];
}

-(void)saveUserData {
    [messageView setHidden:NO];
    [activityIndicator startAnimating];
    
    AFSecurityPolicy *policy = [[AFSecurityPolicy alloc] init];
    [policy setAllowInvalidCertificates:YES];
    
    AFHTTPRequestOperationManager *operationManager = [AFHTTPRequestOperationManager manager];
    [operationManager setSecurityPolicy:policy];
    operationManager.requestSerializer = [AFJSONRequestSerializer serializer];
    operationManager.responseSerializer = [AFJSONResponseSerializer serializer];
    operationManager.responseSerializer.acceptableContentTypes = [operationManager.responseSerializer.acceptableContentTypes setByAddingObject:@"text/html"];
    NSMutableDictionary *requestDict = [NSMutableDictionary dictionaryWithObjectsAndKeys:user.lastName, @"last_name", user.firstName, @"first_name", user.middleName, @"midle_name",
                                 user.email, @"email", user.occupation, @"occupation", [NSString stringWithFormat:@"%ld", (long)([user.birthDate timeIntervalSince1970] * 1000)], @"birthday", nil];
    if (user.userId != nil) {
        [requestDict setValue:user.userId forKey:@"userId"];
    }
    [operationManager POST:ADD_USER_SERVICE_URL
                parameters: requestDict
                   success:^(AFHTTPRequestOperation *operation, id responseObject) {
                       NSLog(@"response: %@", responseObject);
                       NSInteger code = [[responseObject valueForKey:@"result"] integerValue];
                       NSString *message = [responseObject valueForKey:@"message"];
                       NSInteger userId = [[responseObject valueForKey:@"user_id"] integerValue];
                       NSLog(@"code: %d", code);
                       NSLog(@"message: %@", message);
                       NSLog(@"userId: %d", userId);
                       
                       switch (code) {
                           case 200: {
                               user.userId = [NSNumber numberWithInt:userId];
                                [[NSUserDefaults standardUserDefaults] setObject:user.lastName forKey:@"last_name"];
                                [[NSUserDefaults standardUserDefaults] setObject:user.firstName forKey:@"first_name"];
                                [[NSUserDefaults standardUserDefaults] setObject:user.middleName forKey:@"middle_name"];
                                [[NSUserDefaults standardUserDefaults] setObject:user.email forKey:@"email"];
                                [[NSUserDefaults standardUserDefaults] setObject:user.occupation forKey:@"occupation"];
                                [[NSUserDefaults standardUserDefaults] setObject:user.birthDate forKey:@"birthdate"];
                               [[NSUserDefaults standardUserDefaults] setObject:user.userId forKey:@"userId"];
                                [[NSUserDefaults standardUserDefaults] synchronize];
                           
                                UIStoryboard *mainStoryboard = [UIStoryboard storyboardWithName:@"Main" bundle: nil];
                                [self.navigationController pushViewController:[mainStoryboard instantiateViewControllerWithIdentifier:@"MainController"] animated:YES];
                           }
                           break;
                           default:
                           {
                                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка" message:[NSString stringWithFormat:@"Сервер вернул код ошибки: %d", code] delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
                                [alert show];
                           }
                           break;
                       }
                       
                       [messageView setHidden:YES];
                       [activityIndicator stopAnimating];
                   }
                   failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                       [messageView setHidden:YES];
                       [activityIndicator stopAnimating];
                       
                       NSLog(@"######## Error: %@", [error description]);
                       UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"can't connect server. Please check your network." delegate:nil cancelButtonTitle:@"ok" otherButtonTitles:nil];
                       [alert show];
                   }
     ];
}
@end
