package com.isarainc.util;

import android.Manifest;
import android.annotation.TargetApi;
import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.AssetManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Bitmap.Config;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ColorMatrix;
import android.graphics.ColorMatrixColorFilter;
import android.graphics.Matrix;
import android.graphics.Paint;
import android.graphics.Point;
import android.graphics.Rect;
import android.graphics.Shader.TileMode;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.media.ExifInterface;
import android.media.MediaScannerConnection;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.support.v4.app.ActivityCompat;
import android.telephony.TelephonyManager;
import android.util.Log;
import android.view.Display;
import android.view.WindowManager;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.UUID;

public class Utils {
    public static final int REQUEST_EXTERNAL_STORAGE = 1;
    public static final int INTENT_REQUEST_GET_IMAGES = 13;
    private static final String TAG = "Utils";

    private static String[] PERMISSIONS_STORAGE = {
            android.Manifest.permission.READ_EXTERNAL_STORAGE,
            android.Manifest.permission.WRITE_EXTERNAL_STORAGE
    };

    public static boolean hasKitKat() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT;
    }

    @TargetApi(Build.VERSION_CODES.HONEYCOMB_MR2)
    public static int getNewApiWidth(Context mContext) {
        int w = 0;
        WindowManager wm = (WindowManager) mContext
                .getSystemService(Context.WINDOW_SERVICE);
        Display display = wm.getDefaultDisplay();
        Point size = new Point();

        display.getSize(size);
        w = size.x;

        return w;
    }

    /**
     * Checks if the app has permission to write to device storage
     * <p/>
     * If the app does not has permission then the user will be prompted to grant permissions
     *
     * @param activity
     */
    public static boolean verifyStoragePermissions(Activity activity) {
        // Check if we have write permission
        int permission = ActivityCompat.checkSelfPermission(activity, Manifest.permission.WRITE_EXTERNAL_STORAGE);

        if (permission != PackageManager.PERMISSION_GRANTED) {
            // We don't have permission so prompt the user
            ActivityCompat.requestPermissions(
                    activity,
                    PERMISSIONS_STORAGE,
                    REQUEST_EXTERNAL_STORAGE
            );
            return false;
        }
        return true;
    }


    public static Bitmap createContrast(Bitmap src, double value) {
        // image size
        int width = src.getWidth();
        int height = src.getHeight();
        // create output bitmap
        Bitmap bmOut = Bitmap.createBitmap(width, height, src.getConfig());
        // color information
        int A, R, G, B;
        int pixel;
        // get contrast value
        double contrast = Math.pow((100 + value) / 100, 2);

        // scan through all pixels
        for (int x = 0; x < width; ++x) {
            for (int y = 0; y < height; ++y) {
                // get pixel color
                pixel = src.getPixel(x, y);
                A = Color.alpha(pixel);
                // apply filter contrast for every channel R, G, B
                R = Color.red(pixel);
                R = (int) (((((R / 255.0) - 0.5) * contrast) + 0.5) * 255.0);
                if (R < 0) {
                    R = 0;
                } else if (R > 255) {
                    R = 255;
                }

                G = Color.red(pixel);
                G = (int) (((((G / 255.0) - 0.5) * contrast) + 0.5) * 255.0);
                if (G < 0) {
                    G = 0;
                } else if (G > 255) {
                    G = 255;
                }

                B = Color.red(pixel);
                B = (int) (((((B / 255.0) - 0.5) * contrast) + 0.5) * 255.0);
                if (B < 0) {
                    B = 0;
                } else if (B > 255) {
                    B = 255;
                }

                // set new pixel color to output bitmap
                bmOut.setPixel(x, y, Color.argb(A, R, G, B));
            }
        }

        return bmOut;
    }

    public static Bitmap toGrayscale(Bitmap bmpOriginal) {
        int width, height;
        height = bmpOriginal.getHeight();
        width = bmpOriginal.getWidth();

        Bitmap bmpGrayscale = Bitmap.createBitmap(width, height,
                Config.ARGB_8888);
        Canvas c = new Canvas(bmpGrayscale);
        Paint paint = new Paint();
        ColorMatrix cm = new ColorMatrix();
        cm.setSaturation(0);
        ColorMatrixColorFilter f = new ColorMatrixColorFilter(cm);
        paint.setColorFilter(f);
        c.drawBitmap(bmpOriginal, 0, 0, paint);
        return bmpGrayscale;
    }

    @SuppressWarnings("deprecation")
    public static int getOldApiWidth(Context mContext) {
        int w = 0;
        WindowManager wm = (WindowManager) mContext
                .getSystemService(Context.WINDOW_SERVICE);
        Display display = wm.getDefaultDisplay();

        w = display.getWidth(); // deprecated

        return w;
    }

    public static int getWidth(Context mContext) {
        int w = 0;
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.HONEYCOMB) {
            try {
                w = getNewApiWidth(mContext);
            } catch (NoSuchMethodError nme) {
                w = getOldApiWidth(mContext); // deprecated
            }
        } else {
            w = getOldApiWidth(mContext);
        }
        return w;
    }

    @TargetApi(Build.VERSION_CODES.HONEYCOMB_MR2)
    public static int getNewApiHeight(Context mContext) {
        int h = 0;
        WindowManager wm = (WindowManager) mContext
                .getSystemService(Context.WINDOW_SERVICE);
        Display display = wm.getDefaultDisplay();

        Point size = new Point();
        display.getSize(size);
        h = size.y;

        return h;
    }

    @SuppressWarnings("deprecation")
    public static int getOldApiHeight(Context mContext) {
        int h = 0;
        WindowManager wm = (WindowManager) mContext
                .getSystemService(Context.WINDOW_SERVICE);
        Display display = wm.getDefaultDisplay();

        h = display.getHeight(); // deprecated

        return h;
    }

    public static int getHeight(Context mContext) {
        int h = 0;
        if (Build.VERSION.SDK_INT > Build.VERSION_CODES.HONEYCOMB) {
            try {
                h = getNewApiHeight(mContext);
            } catch (NoSuchMethodError nme) {
                h = getOldApiHeight(mContext); // deprecated
            }
        } else {
            h = getOldApiHeight(mContext); // deprecated
        }
        return h;
    }

    /**
     * @param context
     * @param folder
     * @param srcUri
     * @return
     */
    public static File saveFileToGallery(Context context, String folder, Uri srcUri) {
        File cacheFile = new File(srcUri.getPath());
        DiskHelper diskHelper = new DiskHelper();
        File path = new File(diskHelper.getPath(), "Android/" + context.getPackageName() + "/" + folder);
        if (!path.exists()) {
            path.mkdirs();
        }

        File file = new File(path, cacheFile.getName());


        FileInputStream fis = null;
        FileOutputStream fos = null;
        try {
            fis = new FileInputStream(cacheFile);
            fos = new FileOutputStream(file);

            byte[] buffer = new byte[1024];
            int noOfBytes = 0;

            System.out.println("Copying file using streams");

            // read bytes from source file and write to destination file
            while ((noOfBytes = fis.read(buffer)) != -1) {
                fos.write(buffer, 0, noOfBytes);
            }
        } catch (FileNotFoundException e) {
            System.out.println("File not found" + e);
        } catch (IOException ioe) {
            System.out.println("Exception while copying file " + ioe);
        } finally {
            // close the streams using close method
            try {
                if (fis != null) {
                    fis.close();
                }
                if (fos != null) {
                    fos.close();
                }
            } catch (IOException ioe) {
                System.out.println("Error while closing stream: " + ioe);
            }
        }
        MediaScannerConnection.scanFile(context,
                new String[]{
                        file.toString()
                }, null,
                new MediaScannerConnection.OnScanCompletedListener() {
                    @Override
                    public void onScanCompleted(final String path, final Uri uri) {
                        //do nothing
                    }
                });
        return file;
    }


    public static void copyStream(InputStream input, OutputStream output)
            throws IOException {

        byte[] buffer = new byte[1024];
        int bytesRead;
        while ((bytesRead = input.read(buffer)) != -1) {
            output.write(buffer, 0, bytesRead);
        }
    }

    public static boolean isSDCARDMounted() {
        String status = Environment.getExternalStorageState();
        return status.equals(Environment.MEDIA_MOUNTED);
    }

    private static String capitalize(String s) {
        if (s == null || s.length() == 0) {
            return "";
        }
        char first = s.charAt(0);
        if (Character.isUpperCase(first)) {
            return s;
        } else {
            return Character.toUpperCase(first) + s.substring(1);
        }
    }

    public static boolean isTablet(Context context) {
        boolean xlarge = ((context.getResources().getConfiguration().screenLayout & Configuration.SCREENLAYOUT_SIZE_MASK) == 4);
        boolean large = ((context.getResources().getConfiguration().screenLayout & Configuration.SCREENLAYOUT_SIZE_MASK) == Configuration.SCREENLAYOUT_SIZE_LARGE);
        return (xlarge || large);
    }

    public static String getDeviceName() {
        String manufacturer = Build.MANUFACTURER;
        String model = Build.MODEL;
        if (model.startsWith(manufacturer)) {
            return capitalize(model);
        } else {
            return capitalize(manufacturer) + " " + model;
        }
    }

    public static String getAndroidId(Context context) {
        return android.provider.Settings.Secure.getString(
                context.getContentResolver(),
                android.provider.Settings.Secure.ANDROID_ID);
    }

    public static String getDeviceId(Context context) {
        // Get phone number
        TelephonyManager phoneManager = (TelephonyManager) context
                .getApplicationContext().getSystemService(
                        Context.TELEPHONY_SERVICE);
        final String tmDevice, tmSerial, androidId;
        tmDevice = "" + phoneManager.getDeviceId();
        tmSerial = "" + phoneManager.getSimSerialNumber();
        androidId = "" + getAndroidId(context);

        UUID deviceUuid = new UUID(androidId.hashCode(),
                ((long) tmDevice.hashCode() << 32) | tmSerial.hashCode());
        return deviceUuid.toString();
    }

    public static String getCountryCode(Context context) {
        TelephonyManager tm = (TelephonyManager) context
                .getSystemService(Context.TELEPHONY_SERVICE);
        return tm.getSimCountryIso();
    }

    public static boolean hasFroyo() {
        // Can use static final constants like FROYO, declared in later versions
        // of the OS since they are inlined at compile time. This is guaranteed
        // behavior.
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.FROYO;
    }

    public static boolean hasGingerbread() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.GINGERBREAD;
    }

    public static boolean hasHoneycomb() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB;
    }

    public static boolean hasHoneycombMR1() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB_MR1;
    }

    public static boolean hasJellyBean() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN;
    }

    /**
     * Scales the provided bitmap to have the height and width provided.
     * (Alternative method for scaling bitmaps since
     * Bitmap.createScaledBitmap(...) produces bad (blocky) quality bitmaps.)
     *
     * @param bitmap    is the bitmap to scale.
     * @param newWidth  is the desired width of the scaled bitmap.
     * @param newHeight is the desired height of the scaled bitmap.
     * @return the scaled bitmap.
     */
    public static Bitmap scaleBitmap(Bitmap bitmap, int newWidth, int newHeight) {
        Bitmap scaledBitmap = Bitmap.createBitmap(newWidth, newHeight,
                Config.ARGB_8888);

        float scaleX = newWidth / (float) bitmap.getWidth();
        float scaleY = newHeight / (float) bitmap.getHeight();
        float pivotX = 0;
        float pivotY = 0;

        Matrix scaleMatrix = new Matrix();
        scaleMatrix.setScale(scaleX, scaleY, pivotX, pivotY);

        Canvas canvas = new Canvas(scaledBitmap);
        canvas.setMatrix(scaleMatrix);
        canvas.drawBitmap(bitmap, 0, 0, new Paint(Paint.FILTER_BITMAP_FLAG));

        return scaledBitmap;
    }

    /**
     * @param src
     * @param width
     * @param height
     * @return
     */
    public static Bitmap tileBitmap(BitmapDrawable src, int width, int height) {
        Bitmap bmOut = Bitmap.createBitmap(width, height,
                Config.ARGB_8888);
        Canvas canvas = new Canvas(bmOut);
        Rect rect = new Rect(0, 0, width, height);
        // BitmapDrawable mDrawable = (BitmapDrawable)
        // this.getResources().getDrawable(R.drawable.bg_02);
        src.setTileModeXY(TileMode.REPEAT, TileMode.REPEAT);
        src.setBounds(rect);
        src.draw(canvas);
        return bmOut;
    }

    public static Bitmap getBitmapFromAsset(Context context, String filePath) {
        AssetManager assetManager = context.getAssets();

        InputStream istr;
        Bitmap bitmap = null;
        try {
            istr = assetManager.open(filePath);
            bitmap = BitmapFactory.decodeStream(istr);
        } catch (IOException e) {
            // handle exception
            e.printStackTrace();
        }

        return bitmap;
    }

    public static Bitmap scaleBitmap(Bitmap source, float scale, boolean recycle) {
        int newWidth = Math.round(source.getWidth() * scale);
        int newHeight = Math.round(source.getHeight() * scale);
        Bitmap scaleBitmap = Bitmap.createScaledBitmap(source, newWidth, newHeight, true);
        scaleBitmap.setHasAlpha(true);
        if (recycle) {
            source.recycle();
        }
        return scaleBitmap;
    }

    public static Bitmap scaleBitmap(Bitmap source, float scale) {
        return scaleBitmap(source, scale, true);
    }

    public static Bitmap rotateBitmap(Bitmap source, float angle, boolean recycle) {
        Matrix matrix = new Matrix();

        matrix.setRotate(angle, (float) source.getWidth() / 2, (float) source.getHeight() / 2);

        Bitmap rotate = Bitmap.createBitmap(source, 0, 0, source.getWidth(), source.getHeight(), matrix, true);
        if (recycle) {
            source.recycle();
        }
        rotate.setHasAlpha(true);
        //return rotate;
        return trim(rotate);
    }

    public static Bitmap trim(Bitmap source) {
        int firstX = 0, firstY = 0;
        int lastX = source.getWidth();
        int lastY = source.getHeight();
        int[] pixels = new int[source.getWidth() * source.getHeight()];
        source.getPixels(pixels, 0, source.getWidth(), 0, 0, source.getWidth(), source.getHeight());
        loop:
        for (int x = 0; x < source.getWidth(); x++) {
            for (int y = 0; y < source.getHeight(); y++) {
                if (pixels[x + (y * source.getWidth())] != Color.TRANSPARENT) {
                    firstX = x;
                    break loop;
                }
            }
        }
        loop:
        for (int y = 0; y < source.getHeight(); y++) {
            for (int x = firstX; x < source.getHeight(); x++) {
                if (pixels[x + (y * source.getWidth())] != Color.TRANSPARENT) {
                    firstY = y;
                    break loop;
                }
            }
        }
        loop:
        for (int x = source.getWidth() - 1; x >= firstX; x--) {
            for (int y = source.getHeight() - 1; y >= firstY; y--) {
                if (pixels[x + (y * source.getWidth())] != Color.TRANSPARENT) {
                    lastX = x;
                    break loop;
                }
            }
        }
        loop:
        for (int y = source.getHeight() - 1; y >= firstY; y--) {
            for (int x = source.getWidth() - 1; x >= firstX; x--) {
                if (pixels[x + (y * source.getWidth())] != Color.TRANSPARENT) {
                    lastY = y;
                    break loop;
                }
            }
        }
        Bitmap trimed = Bitmap.createBitmap(source, firstX, firstY, lastX - firstX, lastY - firstY);
        trimed.setHasAlpha(true);
        source.recycle();
        return trimed;
    }

    public static Bitmap rotateBitmap(Bitmap source, float angle) {
        return rotateBitmap(source, angle, true);
    }

    public static Bitmap loadBitmap(File file) {
        BitmapFactory.Options options = new BitmapFactory.Options();
        options.inJustDecodeBounds = false;
        options.inPreferredConfig = Config.ARGB_8888;
       // options.inDither = false;
        Bitmap image = null;
        try {

            Bitmap myBitmap = BitmapFactory.decodeFile(file.getPath(),
                    options);

            image = myBitmap;

        } catch (OutOfMemoryError oome) {
            System.gc();
            try {
                image = BitmapFactory.decodeFile(file.getPath(),
                        options);
            } catch (OutOfMemoryError oome2) {
                System.gc();
                options.inSampleSize = 3;
                try {
                    image = BitmapFactory.decodeFile(
                            file.getPath(), options);
                } catch (Exception ignored) {

                }
            }
        }
        ExifInterface exif;
        try {
            exif = new ExifInterface(file.getAbsolutePath());

            int orientation = exif
                    .getAttributeInt(ExifInterface.TAG_ORIENTATION, 1);

            Log.d("ExifInteface .........", "rotation =" + orientation);

            // exif.setAttribute(ExifInterface.ORIENTATION_ROTATE_90, 90);

            Log.d("orientation", "" + orientation);
            Matrix m = new Matrix();
            if ((orientation == 0)) {

            } else if ((orientation == ExifInterface.ORIENTATION_ROTATE_180)) {
                m.postRotate(180);
                // m.postScale((float) bm.getWidth(), (float) bm.getHeight());
                // ifilter(m.preRotate(90)){
                Log.e("in orientation", "" + orientation);
                image = Bitmap.createBitmap(image, 0, 0, image.getWidth(),
                        image.getHeight(), m, true);

            } else if (orientation == ExifInterface.ORIENTATION_ROTATE_90) {
                m.postRotate(90);
                Log.e("in orientation", "" + orientation);
                image = Bitmap.createBitmap(image, 0, 0, image.getWidth(),
                        image.getHeight(), m, true);

            } else if (orientation == ExifInterface.ORIENTATION_ROTATE_270) {
                m.postRotate(270);
                Log.e("in orientation", "" + orientation);
                image = Bitmap.createBitmap(image, 0, 0, image.getWidth(),
                        image.getHeight(), m, true);
            }


        } catch (IOException e1) {

            e1.printStackTrace();
        }
        return image;
    }

    public static Bitmap drawableToBitmap(Drawable drawable) {
        Bitmap bitmap = null;

        if (drawable instanceof BitmapDrawable) {
            BitmapDrawable bitmapDrawable = (BitmapDrawable) drawable;
            if (bitmapDrawable.getBitmap() != null) {
                return bitmapDrawable.getBitmap();
            }
        }

        if (drawable.getIntrinsicWidth() <= 0 || drawable.getIntrinsicHeight() <= 0) {
            bitmap = Bitmap.createBitmap(1, 1, Config.ARGB_8888); // Single color bitmap will be created of 1x1 pixel
        } else {
            bitmap = Bitmap.createBitmap(drawable.getIntrinsicWidth(), drawable.getIntrinsicHeight(), Config.ARGB_8888);
        }

        Canvas canvas = new Canvas(bitmap);
        drawable.setBounds(0, 0, canvas.getWidth(), canvas.getHeight());
        drawable.draw(canvas);
        return bitmap;
    }
}
