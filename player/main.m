#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>

static NSString *const kRoot = @"/var/mobile/Media";

@interface PlayerVC : UIViewController <UITableViewDataSource, UITableViewDelegate, AVAudioPlayerDelegate>
@property (nonatomic, strong) NSMutableArray *tracks;
@property (nonatomic, strong) UITableView *table;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *nowLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) AVAudioPlayer *audio;
@property (nonatomic, assign) NSInteger index;
@end

@implementation PlayerVC

- (UIButton *)makeButton:(NSString *)title frame:(CGRect)f action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.frame = f;
    [b setTitle:title forState:UIControlStateNormal];
    b.titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    b.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return b;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tracks = [NSMutableArray array];
    self.index = -1;
    self.view.backgroundColor = [UIColor blackColor];
    CGRect b = self.view.bounds;

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 24, b.size.width - 20, 24)];
    self.statusLabel.font = [UIFont systemFontOfSize:13];
    self.statusLabel.textColor = [UIColor lightGrayColor];
    self.statusLabel.text = @"Scanning...";
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.statusLabel];

    self.table = [[UITableView alloc] initWithFrame:CGRectMake(0, 52, b.size.width, b.size.height - 52 - 120) style:UITableViewStylePlain];
    self.table.dataSource = self;
    self.table.delegate = self;
    self.table.backgroundColor = [UIColor blackColor];
    self.table.separatorColor = [UIColor darkGrayColor];
    self.table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.table];

    self.nowLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, b.size.height - 112, b.size.width - 20, 34)];
    self.nowLabel.font = [UIFont systemFontOfSize:14];
    self.nowLabel.textColor = [UIColor whiteColor];
    self.nowLabel.textAlignment = NSTextAlignmentCenter;
    self.nowLabel.numberOfLines = 2;
    self.nowLabel.text = @"";
    self.nowLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.nowLabel];

    CGFloat w = b.size.width / 3.0;
    CGFloat y = b.size.height - 70;
    [self.view addSubview:[self makeButton:@"Prev" frame:CGRectMake(0, y, w, 60) action:@selector(prev)]];
    self.playButton = [self makeButton:@"Play" frame:CGRectMake(w, y, w, 60) action:@selector(togglePlay)];
    [self.view addSubview:self.playButton];
    [self.view addSubview:[self makeButton:@"Next" frame:CGRectMake(2 * w, y, w, 60) action:@selector(next)]];

    [self scan];
}

- (void)scan {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSSet *good = [NSSet setWithObjects:@"mp3", @"m4a", @"aac", @"wav", @"aif", @"aiff", @"caf", nil];
        NSSet *bad = [NSSet setWithObjects:@"flac", @"ogg", @"wma", @"opus", nil];
        NSSet *skip = [NSSet setWithObjects:@"DCIM", @"Photos", @"PhotoData", @"PhotoStreamsData", nil];
        NSMutableArray *found = [NSMutableArray array];
        NSInteger unsupported = 0;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDirectoryEnumerator *en = [fm enumeratorAtPath:kRoot];
        for (NSString *rel in en) {
            NSString *first = [[rel pathComponents] firstObject];
            if ([skip containsObject:first]) { [en skipDescendants]; continue; }
            NSString *name = [rel lastPathComponent];
            if ([name hasPrefix:@"."]) { continue; }
            NSString *ext = [[rel pathExtension] lowercaseString];
            if ([good containsObject:ext]) {
                [found addObject:[kRoot stringByAppendingPathComponent:rel]];
            } else if ([bad containsObject:ext]) {
                unsupported++;
            }
        }
        [found sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b2) {
            return [[a lastPathComponent] caseInsensitiveCompare:[b2 lastPathComponent]];
        }];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.tracks = found;
            NSString *msg = [NSString stringWithFormat:@"%lu songs found in %@", (unsigned long)found.count, kRoot];
            if (unsupported > 0) {
                msg = [msg stringByAppendingFormat:@"  (%ld files in unsupported formats: flac/ogg/wma/opus)", (long)unsupported];
            }
            self.statusLabel.text = msg;
            [self.table reloadData];
        });
    });
}

#pragma mark - Table

- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.tracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"cell";
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:cid];
    if (!c) {
        c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cid];
        c.backgroundColor = [UIColor blackColor];
        c.detailTextLabel.textColor = [UIColor grayColor];
    }
    NSString *p = self.tracks[indexPath.row];
    c.textLabel.text = [[p lastPathComponent] stringByDeletingPathExtension];
    c.textLabel.textColor = (indexPath.row == self.index) ? [UIColor greenColor] : [UIColor whiteColor];
    NSString *dir = [[p stringByDeletingLastPathComponent] stringByReplacingOccurrencesOfString:kRoot withString:@""];
    c.detailTextLabel.text = dir.length ? dir : @"/";
    return c;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tv deselectRowAtIndexPath:indexPath animated:YES];
    [self playIndex:indexPath.row];
}

#pragma mark - Playback

- (void)playIndex:(NSInteger)i {
    if (i < 0 || i >= (NSInteger)self.tracks.count) { return; }
    NSError *err = nil;
    NSString *path = self.tracks[i];
    AVAudioPlayer *p = [[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:path] error:&err];
    if (!p) {
        self.nowLabel.text = [NSString stringWithFormat:@"Cannot play: %@", [err localizedDescription]];
        return;
    }
    [self.audio stop];
    p.delegate = self;
    [p prepareToPlay];
    [p play];
    self.audio = p;
    self.index = i;
    [self updateNowPlaying];
    [self.table reloadData];
}

- (void)updateNowPlaying {
    NSString *title = @"";
    if (self.index >= 0 && self.index < (NSInteger)self.tracks.count) {
        title = [[self.tracks[self.index] lastPathComponent] stringByDeletingPathExtension];
    }
    self.nowLabel.text = title;
    [self.playButton setTitle:(self.audio.playing ? @"Pause" : @"Play") forState:UIControlStateNormal];
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = @{
        MPMediaItemPropertyTitle: title,
        MPMediaItemPropertyPlaybackDuration: @(self.audio.duration)
    };
}

- (void)togglePlay {
    if (!self.audio) {
        if (self.tracks.count > 0) { [self playIndex:(self.index >= 0 ? self.index : 0)]; }
        return;
    }
    if (self.audio.playing) { [self.audio pause]; } else { [self.audio play]; }
    [self updateNowPlaying];
}

- (void)next {
    if (self.tracks.count == 0) { return; }
    NSInteger n = self.index + 1;
    if (n >= (NSInteger)self.tracks.count) { n = 0; }
    [self playIndex:n];
}

- (void)prev {
    if (self.tracks.count == 0) { return; }
    if (self.audio && self.audio.currentTime > 3.0) {
        self.audio.currentTime = 0;
        return;
    }
    NSInteger n = self.index - 1;
    if (n < 0) { n = (NSInteger)self.tracks.count - 1; }
    [self playIndex:n];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    if (flag) { [self next]; }
}

#pragma mark - Remote controls (lock screen / headset)

- (BOOL)canBecomeFirstResponder { return YES; }

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    if (event.type != UIEventTypeRemoteControl) { return; }
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlPlay:
            if (self.audio && !self.audio.playing) { [self.audio play]; [self updateNowPlaying]; }
            break;
        case UIEventSubtypeRemoteControlPause:
            if (self.audio && self.audio.playing) { [self.audio pause]; [self updateNowPlaying]; }
            break;
        case UIEventSubtypeRemoteControlTogglePlayPause:
            [self togglePlay];
            break;
        case UIEventSubtypeRemoteControlNextTrack:
            [self next];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack:
            [self prev];
            break;
        default:
            break;
    }
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setActive:YES error:nil];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.rootViewController = [[PlayerVC alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
