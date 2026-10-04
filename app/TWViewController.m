#import "TWViewController.h"
#import <WebKit/WebKit.h>

static NSString *const kHomeURL = @"https://www.tecconcursos.com.br/questoes/pastas";
// Mesmo sufixo do Safari 12: o servidor trata o app como o Safari já testado.
static NSString *const kUserAgentSuffix = @"Version/12.1.2 Mobile/15E148 Safari/604.1";
static NSString *const kRuleListID = @"tec-allowlist";
// Zoom da página inteira (o Ctrl + "+" dos navegadores de desktop); o iOS 12 não tem pageZoom.
static const CGFloat kPageZoom = 1.3;

@interface TWViewController () <WKNavigationDelegate, WKUIDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIToolbar *toolbar;
@property (nonatomic, strong) UIBarButtonItem *backItem;
@property (nonatomic, strong) UIBarButtonItem *forwardItem;
@end

@implementation TWViewController

#pragma mark - Montagem

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = UIColor.whiteColor;

	WKWebViewConfiguration *config = [WKWebViewConfiguration new];
	config.applicationNameForUserAgent = kUserAgentSuffix;
	config.allowsInlineMediaPlayback = YES;
	config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeAll;
	[self addPolyfillsToController:config.userContentController];
	[self addPageZoomToController:config.userContentController];

	self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
	self.webView.navigationDelegate = self;
	self.webView.UIDelegate = self;
	self.webView.allowsBackForwardNavigationGestures = YES;
	self.webView.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:self.webView];

	[self buildToolbar];

	UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
	[NSLayoutConstraint activateConstraints:@[
		[self.webView.topAnchor constraintEqualToAnchor:safe.topAnchor],
		[self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
		[self.webView.bottomAnchor constraintEqualToAnchor:self.toolbar.topAnchor],
		[self.toolbar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
		[self.toolbar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
		[self.toolbar.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
	]];

	[self.webView addObserver:self forKeyPath:@"canGoBack" options:0 context:NULL];
	[self.webView addObserver:self forKeyPath:@"canGoForward" options:0 context:NULL];

	// A allowlist precisa estar ativa antes da primeira carga, senão a página inicial passa sem filtro.
	[self installContentRulesInController:config.userContentController completion:^{
		[self goHome];
	}];
}

- (void)dealloc {
	[self.webView removeObserver:self forKeyPath:@"canGoBack"];
	[self.webView removeObserver:self forKeyPath:@"canGoForward"];
}

- (void)buildToolbar {
	self.toolbar = [UIToolbar new];
	self.toolbar.translatesAutoresizingMaskIntoConstraints = NO;
	[self.view addSubview:self.toolbar];

	self.backItem = [[UIBarButtonItem alloc] initWithTitle:@"‹" style:UIBarButtonItemStylePlain target:self action:@selector(goBack)];
	self.forwardItem = [[UIBarButtonItem alloc] initWithTitle:@"›" style:UIBarButtonItemStylePlain target:self action:@selector(goForward)];
	UIBarButtonItem *reload = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reload)];
	UIBarButtonItem *home = [[UIBarButtonItem alloc] initWithTitle:@"Pastas" style:UIBarButtonItemStylePlain target:self action:@selector(goHome)];
	UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
	NSDictionary *big = @{ NSFontAttributeName: [UIFont systemFontOfSize:34] };
	for (UIBarButtonItem *item in @[ self.backItem, self.forwardItem ]) {
		[item setTitleTextAttributes:big forState:UIControlStateNormal];
		[item setTitleTextAttributes:big forState:UIControlStateDisabled];
		item.enabled = NO;
	}
	self.toolbar.items = @[ self.backItem, flex, self.forwardItem, flex, reload, flex, home ];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	self.backItem.enabled = self.webView.canGoBack;
	self.forwardItem.enabled = self.webView.canGoForward;
}

#pragma mark - Ações da barra

- (void)goBack { [self.webView goBack]; }
- (void)goForward { [self.webView goForward]; }
- (void)reload { [self.webView reload]; }

- (void)goHome {
	[self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:kHomeURL]]];
}

#pragma mark - Scripts de polyfills/

// Mesmas regras do tweak Polyfills: base/ sempre; uma pasta de versão (ex.: 13.0) só quando o iOS
// é mais antigo que ela. scripts/ entra no início do documento e scripts-post/ no fim. Cada arquivo
// roda isolado num try/catch para que um erro não impeça os seguintes.
- (void)addPolyfillsToController:(WKUserContentController *)controller {
	NSString *root = [NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"polyfills"];
	NSDictionary<NSString *, NSNumber *> *dirs = @{
		@"scripts": @(WKUserScriptInjectionTimeAtDocumentStart),
		@"scripts-post": @(WKUserScriptInjectionTimeAtDocumentEnd),
	};
	for (NSString *dir in dirs) {
		NSString *source = [self scriptsInDirectory:[root stringByAppendingPathComponent:dir]];
		if (source.length == 0) continue;
		WKUserScriptInjectionTime time = (WKUserScriptInjectionTime)dirs[dir].integerValue;
		[controller addUserScript:[[WKUserScript alloc] initWithSource:source injectionTime:time forMainFrameOnly:NO]];
	}
}

- (NSString *)scriptsInDirectory:(NSString *)path {
	NSFileManager *fm = NSFileManager.defaultManager;
	NSString *system = UIDevice.currentDevice.systemVersion;
	NSMutableArray<NSString *> *subdirs = [NSMutableArray array];
	for (NSString *name in [[fm contentsOfDirectoryAtPath:path error:nil] sortedArrayUsingSelector:@selector(compare:)]) {
		BOOL isVersion = [name rangeOfString:@"^\\d+\\.\\d+$" options:NSRegularExpressionSearch].location != NSNotFound;
		if ([name isEqualToString:@"base"] ||
			(isVersion && [system compare:name options:NSNumericSearch] == NSOrderedAscending)) {
			[subdirs addObject:name];
		}
	}

	NSMutableString *source = [NSMutableString string];
	for (NSString *subdir in subdirs) {
		NSString *dirPath = [path stringByAppendingPathComponent:subdir];
		for (NSString *file in [[fm contentsOfDirectoryAtPath:dirPath error:nil] sortedArrayUsingSelector:@selector(compare:)]) {
			if (![file.pathExtension isEqualToString:@"js"]) continue;
			NSString *js = [NSString stringWithContentsOfFile:[dirPath stringByAppendingPathComponent:file] encoding:NSUTF8StringEncoding error:nil];
			if (!js) continue;
			[source appendFormat:@"try {\n%@\n} catch (e) { console.error('TecDuck: %@ falhou', e); }\n", js, file];
		}
	}
	return source;
}

#pragma mark - Zoom da página

// Diagrama a página com largura menor (tela / zoom) e deixa o WebKit escalar o resultado: texto,
// botões e setas crescem juntos e os toques continuam alinhados, ao contrário do zoom do CSS.
// O observer só acompanha a análise do HTML, onde o site grava a própria meta viewport.
- (void)addPageZoomToController:(WKUserContentController *)controller {
	NSString *source = [NSString stringWithFormat:@
		"(function () {\n"
		"  var ZOOM = %.2f;\n"
		"  function content() {\n"
		"    var landscape = Math.abs(window.orientation || 0) === 90;\n"
		"    var side = landscape ? Math.max(screen.width, screen.height) : Math.min(screen.width, screen.height);\n"
		"    return 'width=' + Math.round(side / ZOOM) + ', initial-scale=' + ZOOM;\n"
		"  }\n"
		"  function apply() {\n"
		"    var meta = document.querySelector('meta[name=viewport]');\n"
		"    if (!meta) {\n"
		"      if (!document.head) return;\n"
		"      meta = document.createElement('meta');\n"
		"      meta.name = 'viewport';\n"
		"      document.head.appendChild(meta);\n"
		"    }\n"
		"    var wanted = content();\n"
		"    if (meta.content !== wanted) meta.content = wanted;\n"
		"  }\n"
		"  var observer = new MutationObserver(apply);\n"
		"  observer.observe(document.documentElement, { childList: true, subtree: true });\n"
		"  document.addEventListener('DOMContentLoaded', function () { observer.disconnect(); apply(); });\n"
		"  window.addEventListener('orientationchange', apply);\n"
		"})();\n", kPageZoom];
	[controller addUserScript:[[WKUserScript alloc] initWithSource:source
	                                                 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
	                                              forMainFrameOnly:YES]];
}

#pragma mark - Allowlist de subrecursos

- (void)installContentRulesInController:(WKUserContentController *)controller completion:(void (^)(void))completion {
	NSString *path = [NSBundle.mainBundle pathForResource:@"content-rules" ofType:@"json"];
	NSString *rules = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
	if (!rules) {
		NSLog(@"TecDuck: content-rules.json ausente; carregando sem allowlist");
		completion();
		return;
	}
	[WKContentRuleListStore.defaultStore compileContentRuleListForIdentifier:kRuleListID
	                                                  encodedContentRuleList:rules
	                                                       completionHandler:^(WKContentRuleList *list, NSError *error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			if (list) {
				[controller addContentRuleList:list];
			} else {
				NSLog(@"TecDuck: allowlist inválida: %@", error);
			}
			completion();
		});
	}];
}

#pragma mark - Política de navegação

static BOOL TWHostIs(NSString *host, NSString *domain) {
	host = host.lowercaseString;
	return [host isEqualToString:domain] || [host hasSuffix:[@"." stringByAppendingString:domain]];
}

// Páginas que abrem no próprio app quando navegam o quadro principal.
static BOOL TWStaysInApp(NSURL *url) {
	if (TWHostIs(url.host, @"tecconcursos.com.br")) return YES;
	BOOL recaptchaHost = TWHostIs(url.host, @"google.com") || TWHostIs(url.host, @"recaptcha.net");
	return recaptchaHost && [url.path hasPrefix:@"/recaptcha/"];
}

// youtube.com/watch?v=ID[&t=..] ou youtu.be/ID -> ytlite://watch?v=ID[&t=..] (Opaline).
static NSURL *TWOpalineURL(NSURL *url) {
	NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
	NSString *videoID = nil;
	NSString *start = nil;
	for (NSURLQueryItem *item in components.queryItems) {
		if ([item.name isEqualToString:@"v"]) videoID = item.value;
		if ([item.name isEqualToString:@"t"] || [item.name isEqualToString:@"start"]) start = item.value;
	}
	if (TWHostIs(url.host, @"youtu.be")) {
		videoID = url.path.lastPathComponent;
	} else if (!TWHostIs(url.host, @"youtube.com") || ![url.path isEqualToString:@"/watch"]) {
		return nil;
	}
	if (videoID.length == 0) return nil;
	NSString *target = [NSString stringWithFormat:@"ytlite://watch?v=%@", videoID];
	if (start.length > 0) {
		target = [target stringByAppendingFormat:@"&t=%ld", (long)start.integerValue];
	}
	return [NSURL URLWithString:target];
}

- (void)openExternally:(NSURL *)url {
	[UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
}

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
	NSURL *url = action.request.URL;
	NSString *scheme = url.scheme.lowercaseString;

	if ([@[ @"about", @"data", @"blob" ] containsObject:scheme]) {
		decisionHandler(WKNavigationActionPolicyAllow);
		return;
	}
	if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) {
		// ytlite:, mailto:, tel: e afins ficam com o app do sistema.
		[self openExternally:url];
		decisionHandler(WKNavigationActionPolicyCancel);
		return;
	}
	// Iframes (reCAPTCHA, player sob demanda) seguem a allowlist de subrecursos.
	if (action.targetFrame && !action.targetFrame.isMainFrame) {
		decisionHandler(WKNavigationActionPolicyAllow);
		return;
	}
	if (TWStaysInApp(url)) {
		decisionHandler(WKNavigationActionPolicyAllow);
		return;
	}
	NSURL *opaline = TWOpalineURL(url);
	[self openExternally:opaline ?: url];
	decisionHandler(WKNavigationActionPolicyCancel);
}

// target=_blank e window.open: uma aba só, então abre na mesma página (ou fora do app).
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)windowFeatures {
	NSURL *url = action.request.URL;
	if (TWStaysInApp(url)) {
		[webView loadRequest:action.request];
	} else if (url) {
		NSURL *opaline = TWOpalineURL(url);
		[self openExternally:opaline ?: url];
	}
	return nil;
}

// Com 1 GB de RAM o jetsam pode matar o processo da página; recarrega em vez de deixar a tela vazia.
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
	NSLog(@"TecDuck: processo WebContent encerrado; recarregando");
	if (webView.URL) {
		[webView reload];
	} else {
		[self goHome];
	}
}

#pragma mark - alert, confirm e prompt

- (void)presentAlert:(UIAlertController *)alert {
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { completionHandler(); }]];
	[self presentAlert:alert];
}

- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) { completionHandler(NO); }]];
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { completionHandler(YES); }]];
	[self presentAlert:alert];
}

- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))completionHandler {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:prompt preferredStyle:UIAlertControllerStyleAlert];
	[alert addTextFieldWithConfigurationHandler:^(UITextField *field) { field.text = defaultText; }];
	[alert addAction:[UIAlertAction actionWithTitle:@"Cancelar" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) { completionHandler(nil); }]];
	__weak UIAlertController *weakAlert = alert;
	[alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { completionHandler(weakAlert.textFields.firstObject.text); }]];
	[self presentAlert:alert];
}

@end
