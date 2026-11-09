package app.misrutas;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebChromeClient;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.webkit.ValueCallback;
import android.webkit.WebResourceRequest;
import android.webkit.WebResourceResponse;
import android.content.Intent;
import android.net.Uri;
import android.content.res.AssetManager;
import java.io.InputStream;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.util.Locale;

public class MainActivity extends Activity {
    private WebView web;
    private ValueCallback<Uri[]> fileCallback;
    private static final int PICK_FILE = 42;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        web = new WebView(this);
        web.getSettings().setJavaScriptEnabled(true);
        web.getSettings().setDomStorageEnabled(true);
        web.getSettings().setDatabaseEnabled(true);
        web.getSettings().setAllowFileAccess(true);
        web.getSettings().setAllowContentAccess(true);
        web.setWebViewClient(new WebViewClient() {
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, WebResourceRequest request) {
                return assetResponse(request.getUrl());
            }
            @Override public WebResourceResponse shouldInterceptRequest(WebView view, String url) {
                return assetResponse(Uri.parse(url));
            }
            private WebResourceResponse assetResponse(Uri uri) {
                if (!"appassets.androidplatform.net".equals(uri.getHost()) || !uri.getPath().startsWith("/assets/")) return null;
                String name = uri.getPath().substring("/assets/".length());
                try {
                    InputStream in = getAssets().open(name);
                    String lower = name.toLowerCase(Locale.ROOT);
                    String mime = lower.endsWith(".js") ? "text/javascript" : lower.endsWith(".svg") ? "image/svg+xml" : lower.endsWith(".webmanifest") || lower.endsWith(".json") ? "application/manifest+json" : lower.endsWith(".html") ? "text/html" : "application/octet-stream";
                    return new WebResourceResponse(mime, "UTF-8", in);
                } catch (IOException missing) {
                    return new WebResourceResponse("text/plain", "UTF-8", new ByteArrayInputStream(new byte[0]));
                }
            }
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                Intent pick = new Intent(Intent.ACTION_GET_CONTENT);
                pick.addCategory(Intent.CATEGORY_OPENABLE);
                pick.setType("*/*");
                startActivityForResult(Intent.createChooser(pick, "Elige una foto o recorrido"), PICK_FILE);
                return true;
            }
        });
        setContentView(web);
        loadAppUrl(getIntent());
    }

    private void loadAppUrl(Intent intent) {
        Uri data = intent == null ? null : intent.getData();
        if (data != null && "misrutas".equals(data.getScheme()) && "recovery".equals(data.getHost()) && data.getFragment() != null) {
            web.loadUrl("https://appassets.androidplatform.net/assets/index.html#" + data.getFragment());
        } else {
            web.loadUrl("https://appassets.androidplatform.net/assets/index.html");
        }
    }

    @Override protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        if (web != null) loadAppUrl(intent);
    }

    @Override protected void onActivityResult(int request, int result, Intent data) {
        super.onActivityResult(request, result, data);
        if (request == PICK_FILE && fileCallback != null) {
            Uri[] files = result == RESULT_OK && data != null && data.getData() != null ? new Uri[]{data.getData()} : null;
            fileCallback.onReceiveValue(files);
            fileCallback = null;
        }
    }

    @Override public void onBackPressed() {
        if (web != null && web.canGoBack()) web.goBack(); else super.onBackPressed();
    }
}
