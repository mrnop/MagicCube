package com.isarainc.magiccube.service;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Path;
import android.graphics.PorterDuff;
import android.graphics.PorterDuffXfermode;
import android.os.Environment;
import android.provider.Settings;
import android.util.Log;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;
import com.isarainc.magiccube.R;
import com.isarainc.magiccube.model.Magic;
import com.isarainc.magiccube.model.Page;
import com.isarainc.magiccube.model.PagePreview;
import com.isarainc.magiccube.model.Save;
import com.isarainc.util.Utils;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.FileWriter;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.Writer;
import java.lang.reflect.Type;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.LinkedList;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public class MagicManager {
    public static final Gson gson = new GsonBuilder()
            .setDateFormat("yyyy-MM-dd HH:mm:ss")
            .create();
    private static final String TAG = "MagicManager";
    private static MagicManager instance;
    private final Context mContext;
    private String androidId = null;
    private List<String> devices = new LinkedList<>();

    private MagicManager(Context context) {
        this.mContext = context;
        androidId = Settings.Secure.getString(context.getContentResolver(),
                Settings.Secure.ANDROID_ID);
        Log.d(TAG,"androidId=" +androidId);
        InputStream istr;
        StringBuilder sb = new StringBuilder();
        BufferedReader br = null;
        try {
            istr = mContext.getAssets().open("devices.json");
            br = new BufferedReader(new InputStreamReader(istr));
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line);
            }
            Type type = new TypeToken<List<String>>() {
            }.getType();
            devices = gson.fromJson(sb.toString(), type);
        } catch (IOException e) {
            Log.w(TAG, "Devices ", e);
            e.printStackTrace();
        } finally {
            if (br != null) {
                try {
                    br.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }

    }
    private boolean isVip(){
        return  devices.contains(androidId);
    }

    public static MagicManager getInstance(Context context) {
        if (instance == null) {
            instance = new MagicManager(context);
        }
        return instance;
    }

    public static boolean assetExists(Context context, String path) {
        boolean bAssetOk = false;
        try {
            InputStream stream = context.getAssets().open(path);
            stream.close();
            bAssetOk = true;
        } catch (FileNotFoundException e) {
            Log.w(TAG, "assetExists failed: " + e.toString());
        } catch (IOException e) {
            Log.w(TAG, "assetExists failed: " + e.toString());
        }
        return bAssetOk;
    }

    public File getWorkDir() {
        File dir = null;
        if (Utils.isSDCARDMounted()) {
            dir = new File(
                    Environment.getExternalStorageDirectory()
                            + File.separator + "Android"
                            + File.separator + "data"
                            + File.separator + mContext.getPackageName()
                            + File.separator + "workspace");
        } else {
            dir = new File(
                    Environment.getDataDirectory().getPath()
                            + File.separator + mContext.getPackageName()
                            + File.separator + "workspace");
        }
        return dir;
    }

    public List<Magic> listMagics() {
        List<Magic> magics = new LinkedList<>();
        try {
            String[] dirs = mContext.getAssets().list("magics");
            for (String dir : dirs) {

                if (assetExists(mContext, "magics/" + dir + "/meta.json")) {
                    try {
                        Magic magic = loadMagic(dir);
                        magics.add(magic);
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }
            }

        } catch (IOException e) {
            e.printStackTrace();
        }
        return magics;
    }

    /**
     * @param magicPath
     * @param file
     * @return
     */
    public Bitmap loadMagicBitmap(String magicPath, String file) {
        InputStream istr = null;
        Bitmap bitmap = null;

        try {
            istr = mContext.getAssets().open("magics/" + magicPath + "/" + file);
            bitmap = BitmapFactory.decodeStream(istr);

        } catch (IOException e) {
            Log.w(TAG, "loadMagicBitmap ", e);
            e.printStackTrace();
        } finally {
            if (istr != null) {
                try {
                    istr.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        return bitmap;
    }

    public Magic loadMagic(String path) {
        InputStream istr;
        StringBuilder sb = new StringBuilder();
        BufferedReader br = null;
        try {
            istr = mContext.getAssets().open("magics/" + path + "/meta.json");
            br = new BufferedReader(new InputStreamReader(istr));
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line);
            }

        } catch (IOException e) {
            Log.w(TAG, "loadMagic ", e);
            e.printStackTrace();
        } finally {
            if (br != null) {
                try {
                    br.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }

        Magic magic = gson.fromJson(sb.toString(), Magic.class);
        // Log.d(TAG, "magic =" + magic + " on path " + path);
        if (magic != null) {
            magic.setPath(path);
        }

        return magic;
    }

    public List<Page.Head> listPages(String magic) {
        List<Page.Head> pages = new LinkedList<>();
        try {
            String[] dirs = mContext.getAssets().list("magics/" + magic + "/pages");
            for (String dir : dirs) {
                if (assetExists(mContext, "magics/" + magic + "/pages/" + dir + "/meta.json")) {
                    Page.Head page = loadPage(magic, dir);
                    pages.add(page);
                }

            }

        } catch (IOException e) {
            e.printStackTrace();
        }
        return pages;
    }

    public Page.Head loadPage(String magicPath, String pagePath) {
        InputStream istr;
        StringBuilder sb = new StringBuilder();
        BufferedReader br = null;
        try {
            istr = mContext.getAssets().open("magics/" + magicPath + "/pages/" + pagePath + "/meta.json");
            br = new BufferedReader(new InputStreamReader(istr));
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line);
            }

        } catch (IOException e) {
            Log.w(TAG, "loadPage ", e);
            e.printStackTrace();
        } finally {
            if (br != null) {
                try {
                    br.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }

        Page.Head head = gson.fromJson(sb.toString(), Page.Head.class);
        //Log.d(TAG, "head =" + head);
        if (head != null) {
            head.setPath(pagePath);
        }

        return head;
    }


    public List<Save> listSaves() {
        List<Save> saves = new LinkedList<>();
        File workDir = getWorkDir();
        File dirs[] = workDir.listFiles();
        if (dirs != null) {
            for (File dir : dirs) {
                File meta = new File(dir, "meta.json");
                if (meta.exists()) {
                    Save save = loadSave(dir.getName());
                    if (save != null) {
                        Magic magic = loadMagic(save.getMagic());
                        if (magic == null) {
                            deleteSave(dir.getName());
                        }
                        saves.add(0, save);
                    } else {
                        deleteSave(dir.getName());
                    }
                }
            }
        }
        Collections.sort(saves, new Comparator<Save>() {
            @Override
            public int compare(Save save, Save t1) {
                return t1.getUpdated().compareTo(save.getUpdated());
            }
        });
        return saves;
    }

    public String nextFileName(String magic) {
        File dir = getWorkDir();
        int i = 1;
        while (true) {
            File file = new File(dir, String.format(Locale.getDefault(), "%s%d", magic, i));
            if (!file.exists()) {
                return file.getName();
            }
            i++;
        }
    }

    public Save loadSave(String path) {
        File workDir = getWorkDir();
        File file = new File(workDir, path + File.separator + "meta.json");

        StringBuilder sb = new StringBuilder();
        BufferedReader br = null;
        try {
            br = new BufferedReader(new FileReader(file));
            String line;
            while ((line = br.readLine()) != null) {
                sb.append(line);
            }

        } catch (IOException e) {
            Log.w(TAG, "loadSave ", e);
            e.printStackTrace();
        } finally {
            if (br != null) {
                try {
                    br.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            }
        }
        Save save = gson.fromJson(sb.toString(), Save.class);
        //  Log.d(TAG, "save =" + save);
        if (save != null) {
            save.setPath(path);

        }
        return save;

    }


    public void createMagic(String magic, String path) {
        File workDir = getWorkDir();
        File dir = new File(workDir, path);
        if (!dir.exists()) {
            dir.mkdirs();
        }
        Save save = new Save();
        save.setName(path);
        save.setPath(path);
        save.setAuthor("Me");
        save.setCreated(new Date());
        save.setUpdated(new Date());
        save.setMagic(magic);
        try {
            Writer output = null;
            File file = new File(dir, "meta.json");
            output = new BufferedWriter(new FileWriter(file));
            output.write(gson.toJson(save));
            output.close();
            //Toast.makeText(getApplicationContext(), "Composition saved", Toast.LENGTH_LONG).show();

        } catch (Exception e) {
            e.printStackTrace();
            //Toast.makeText(getBaseContext(), e.getMessage(), Toast.LENGTH_LONG).show();
        }

    }

    public void updateSave(Save save) {
        File workDir = getWorkDir();
        File dir = new File(workDir, save.getPath());

        save.setUpdated(new Date());
        try {
            Writer output = null;
            File file = new File(dir, "meta.json");
            output = new BufferedWriter(new FileWriter(file));
            output.write(gson.toJson(save));
            output.close();
            //Toast.makeText(mContext, "Composition saved", Toast.LENGTH_LONG).show();

        } catch (Exception e) {
            e.printStackTrace();
            // Toast.makeText(mContext, e.getMessage(), Toast.LENGTH_LONG).show();
        }

    }

    public void deleteRecursive(File fileOrDirectory) {
        if (fileOrDirectory.isDirectory())
            for (File child : fileOrDirectory.listFiles())
                deleteRecursive(child);

        fileOrDirectory.delete();
    }

    public void deleteSave(String name) {
        File workDir = getWorkDir();
        File dir = new File(workDir, name);
        // Log.d(TAG, "deleteSave " + dir);
        if (dir.exists()) {
            deleteRecursive(dir);
        }
    }

    public Bitmap loadSlice(String name, int source, int slice) {

        File workDir = getWorkDir();
        File dir = new File(workDir, name + File.separator + source);
        File file = new File(dir, String.format(Locale.getDefault(), "%s.png", slice));

        if (file.exists()) {
            BitmapFactory.Options options = new BitmapFactory.Options();
            options.inJustDecodeBounds = false;
            options.inPreferredConfig = Bitmap.Config.ARGB_8888;
            try {
                return BitmapFactory.decodeFile(file.getPath(),
                        options);
            } catch (OutOfMemoryError oome) {
                oome.printStackTrace();
            }
        }
        return null;
    }

    protected Bitmap slice(Bitmap bitmap, int x, int y, int w, int h) {
        Bitmap bm = Bitmap.createBitmap(w, h,
                Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bm);
        canvas.drawBitmap(bitmap, x * (-1), y * (-1), null);
        return bm;
    }

    private Bitmap cropPolygon(Bitmap bitmap, List<Magic.Point> points) {
        //find new width height
        int minX = Integer.MAX_VALUE;
        int maxX = -Integer.MAX_VALUE;
        int minY = Integer.MAX_VALUE;
        int maxY = -Integer.MAX_VALUE;

        Path path = new Path();
        int i = 0;
        for (Magic.Point point : points) {

            int x = point.getX();
            int y = point.getY();

            if (i == 0) {
                path.moveTo(x, y);
                i++;
            } else {
                path.lineTo(x, y);
            }

            minX = Math.min(minX, x);
            maxX = Math.max(maxX, x);
            minY = Math.min(minY, y);
            maxY = Math.max(maxY, y);
        }

        int width = maxX - minX;
        int height = maxY - minY;
        // Log.d(TAG, "x,y=" + minX + ":" + minY);
        //  Log.d(TAG, "---------------");
        Bitmap cropImage = Bitmap.createBitmap(bitmap.getWidth(), bitmap.getHeight(), Bitmap.Config.ARGB_8888);

        Canvas canvas = new Canvas(cropImage);
        Paint paint = new Paint();
        paint.setAntiAlias(true);
        canvas.drawPath(path, paint);

        paint.setXfermode(new PorterDuffXfermode(PorterDuff.Mode.SRC_IN));
        canvas.drawBitmap(bitmap, 0, 0, paint);

        Bitmap resultImage = Bitmap.createBitmap((int) width, (int) height, Bitmap.Config.ARGB_8888);
        Canvas resultCanvas = new Canvas(resultImage);
        resultCanvas.drawBitmap(cropImage, -minX, -minY, new Paint());
        cropImage.recycle();
        return resultImage;
    }


    public List<Bitmap> slice(Magic.Source source, Bitmap mBitmap) {
        List<Bitmap> bms = new LinkedList<Bitmap>();

        for (Magic.Slice slice : source.getSlices()) {
            Bitmap bm = cropPolygon(mBitmap, slice.getPolygon());
            Log.d(TAG, "slice " + slice.getId());

            if (slice.getTransforms() != null && !slice.getTransforms().isEmpty()) {
                for (Magic.Transform transform : slice.getTransforms()) {
                    Log.d(TAG, "transform " + transform.getType());
                    if ("perspective".equals(transform.getType())) {
                        Log.d(TAG, "bm before perspective size=" + bm.getWidth() + "x" + bm.getHeight());
                        bm = applyPerspectiveTransform(bm, transform.getParams());
                        Log.d(TAG, "bm after perspective size=" + bm.getWidth() + "x" + bm.getHeight());
                    } else if ("rotate".equals(transform.getType())) {
                        Magic.RotateTransform rotateTransform = new Magic.RotateTransform(slice, transform.getParams());
                        bm = Utils.trim(rotateTransform.transform(bm));
                    } else if ("scale".equals(transform.getType())) {
                        Magic.ScaleTransform scaleTransform = new Magic.ScaleTransform(slice, transform.getParams());
                        bm = scaleTransform.transform(bm);
                    }
                }
            }

            bms.add(bm);

        }
        return bms;
    }

    private Bitmap addWaterMark(Bitmap src, Bitmap wm) {
        int w = src.getWidth();
        int h = src.getHeight();
        int min = w < h ? w : h;
        Bitmap result = Bitmap.createBitmap(w, h, src.getConfig());
        Canvas canvas = new Canvas(result);
        canvas.drawBitmap(src, 0, 0, null);

        float scale = ((float) min / 2) / wm.getWidth();
        wm = Utils.scaleBitmap(wm, scale);
        canvas.drawBitmap(wm, (w - wm.getWidth()) / 2, (h - wm.getHeight()) / 2, null);
        src.recycle();
        return result;
    }

    public Bitmap createText(Magic.Text text){
        //find new width height
        int minX = Integer.MAX_VALUE;
        int maxX = -Integer.MAX_VALUE;
        int minY = Integer.MAX_VALUE;
        int maxY = -Integer.MAX_VALUE;

        Path path = new Path();
        int i = 0;
        for (Magic.Point point : text.getPolygon()) {

            int x = point.getX();
            int y = point.getY();

            if (i == 0) {
                path.moveTo(x, y);
                i++;
            } else {
                path.lineTo(x, y);
            }

            minX = Math.min(minX, x);
            maxX = Math.max(maxX, x);
            minY = Math.min(minY, y);
            maxY = Math.max(maxY, y);
        }

        int width = maxX - minX;
        int height = maxY - minY;
        // Log.d(TAG, "x,y=" + minX + ":" + minY);
        //  Log.d(TAG, "---------------");
        Bitmap txtBitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);

        Canvas canvas = new Canvas(txtBitmap);
        Paint paint = new Paint();
        paint.setAntiAlias(true);
        paint.setColor(Color.parseColor(text.getBackground()));
        paint.setStyle(Paint.Style.FILL);
        canvas.drawPath(path, paint);

        return txtBitmap;
    }

    /**
     * Apply perspective transformation to a bitmap using Android Matrix
     * @param bitmap The source bitmap to transform
     * @param params Transform parameters containing perspective values
     * @return The transformed bitmap
     */
    private Bitmap applyPerspectiveTransform(Bitmap bitmap, Map<String, Object> params) {
        if (bitmap == null || params == null) {
            Log.w(TAG, "Invalid parameters for perspective transform");
            return bitmap;
        }

        try {
            // Get perspective parameters
            float[] src = getPerspectivePoints(params, "src", bitmap.getWidth(), bitmap.getHeight());
            float[] dst = getPerspectivePoints(params, "dst", bitmap.getWidth(), bitmap.getHeight());
            
            if (src == null || dst == null) {
                Log.w(TAG, "Missing perspective points, skipping transform");
                return bitmap;
            }

            // Create transformation matrix
            android.graphics.Matrix matrix = new android.graphics.Matrix();
            if (!matrix.setPolyToPoly(src, 0, dst, 0, 4)) {
                Log.w(TAG, "Failed to create perspective matrix");
                return bitmap;
            }

            // Calculate output bitmap dimensions
            float[] bounds = calculateTransformedBounds(dst);
            int width = Math.max(1, (int) Math.ceil(bounds[2] - bounds[0]));
            int height = Math.max(1, (int) Math.ceil(bounds[3] - bounds[1]));

            // Apply transformation
            Bitmap transformed = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);
            Canvas canvas = new Canvas(transformed);
            
            // Adjust matrix to account for bounds offset
            matrix.postTranslate(-bounds[0], -bounds[1]);
            
            canvas.drawBitmap(bitmap, matrix, new Paint(Paint.ANTI_ALIAS_FLAG | Paint.FILTER_BITMAP_FLAG));
            
            Log.d(TAG, "Perspective transform applied: " + bitmap.getWidth() + "x" + bitmap.getHeight() + 
                  " -> " + width + "x" + height);
            
            return transformed;
            
        } catch (Exception e) {
            Log.e(TAG, "Error applying perspective transform", e);
            return bitmap;
        }
    }

    /**
     * Extract perspective points from transform parameters
     */
    private float[] getPerspectivePoints(Map<String, Object> params, String key, int width, int height) {
        Object pointsObj = params.get(key);
        if (pointsObj == null) {
            // Fallback to default corner points
            if ("src".equals(key)) {
                return new float[]{0, 0, width, 0, width, height, 0, height};
            }
            return null;
        }

        try {
            if (pointsObj instanceof List) {
                @SuppressWarnings("unchecked")
                List<Object> pointsList = (List<Object>) pointsObj;
                if (pointsList.size() >= 8) {
                    float[] points = new float[8];
                    for (int i = 0; i < 8; i++) {
                        Object val = pointsList.get(i);
                        if (val instanceof Number) {
                            points[i] = ((Number) val).floatValue();
                        } else if (val instanceof String) {
                            points[i] = Float.parseFloat((String) val);
                        }
                    }
                    return points;
                }
            } else if (pointsObj instanceof String) {
                String[] parts = ((String) pointsObj).split(",");
                if (parts.length >= 8) {
                    float[] points = new float[8];
                    for (int i = 0; i < 8; i++) {
                        points[i] = Float.parseFloat(parts[i].trim());
                    }
                    return points;
                }
            }
        } catch (Exception e) {
            Log.w(TAG, "Error parsing perspective points for " + key, e);
        }

        return null;
    }

    /**
     * Calculate the bounding box of transformed points
     */
    private float[] calculateTransformedBounds(float[] points) {
        float minX = Float.MAX_VALUE;
        float maxX = Float.MIN_VALUE;
        float minY = Float.MAX_VALUE;
        float maxY = Float.MIN_VALUE;

        for (int i = 0; i < points.length; i += 2) {
            float x = points[i];
            float y = points[i + 1];
            minX = Math.min(minX, x);
            maxX = Math.max(maxX, x);
            minY = Math.min(minY, y);
            maxY = Math.max(maxY, y);
        }

        return new float[]{minX, minY, maxX, maxY};
    }

    public List<PagePreview> build(String name, String magicPath, String page) {

        List<PagePreview> bms = new LinkedList<>();
        File workDir = getWorkDir();
        File dir = new File(workDir, name + File.separator + "build");
        if (!dir.exists()) {
            dir.mkdirs();
        }
        Page.Head ph = loadPage(magicPath, page);
        Magic magic = loadMagic(magicPath);

        if (ph != null) {
            for (Page p : ph.getPages()) {
                Bitmap template = Utils.getBitmapFromAsset(mContext, "magics/" + magicPath + "/pages/" + page + "/" + p.getFile());
                // int imageWidth = template.getWidth();
                int templateHeight = template.getHeight();
                float printScale =  (float) ph.getWidth() / template.getWidth();
                template = Utils.scaleBitmap(template,printScale);

                Bitmap workBitmap = Bitmap.createBitmap(ph.getWidth(), ph.getHeight(),
                        Bitmap.Config.ARGB_8888);
                Canvas canvas = new Canvas(workBitmap);
                canvas.drawColor(Color.WHITE);


                for (Page.Face face : p.getFaces()) {
                    buildFace(canvas ,name,magic, face, templateHeight,printScale,
                            p.getOffsetX() ,p.getOffsetY(), ph.getScale() , ph.getDpi() , ph.getGrid() );

                }

                for (Page.Section section : p.getSections()) {
                    for (Page.Face face : section.getFaces()) {
                        buildFace(canvas ,name,magic , face, templateHeight,printScale,
                                section.getOffsetX(),section.getOffsetY(),section.getScale(),section.getDpi(), section.getGrid() );

                    }

                }
                if (p.getTexts()!=null && !p.getTexts().isEmpty()) {

                    for(Page.TextFace textFace : p.getTexts()){
                        Magic.Text text = null;
                        //Find Magic Text
                        if (magic != null) {
                            for (Magic.Text txt : magic.getTexts()) {

                                if (txt.getId() == textFace.getText()) {
                                    text = txt;
                                    break;
                                }

                            }
                        }
                        //draw Text
                        if(text!=null) {
                            Bitmap txtBm = createText(text);
                            //Utils.getBitmapFromAsset(mContext, "magics/" + magicPath + "/pages/" + page + "/" + watermark.getSrc());


                            if (textFace.getAngle() != 0) {
                                txtBm = Utils.rotateBitmap(txtBm, textFace.getAngle());
                            }
                            if (p.getOffsetY() > 0) {
                                canvas.drawBitmap(txtBm, (p.getOffsetX() / 96 + (textFace.getX() * ph.getGrid() / 96)) * printScale * ph.getDpi(),
                                        ((templateHeight - p.getOffsetY() / 96 * ph.getDpi()) + ((textFace.getY() * ph.getGrid() / 96) * ph.getDpi())) * printScale, null);
                            } else if (p.getOffsetX() > 0) {
                                canvas.drawBitmap(txtBm, (p.getOffsetX() / 96 + (textFace.getX() * ph.getGrid() / 96)) * printScale * ph.getDpi(),
                                        (templateHeight - ((textFace.getY() / 96) * ph.getGrid() * ph.getDpi())) * printScale, null);
                            } else {
                                canvas.drawBitmap(txtBm, (textFace.getX() / 96) * ph.getGrid() * printScale * ph.getDpi(),
                                        (templateHeight - ((textFace.getY() / 96) * ph.getGrid() * ph.getDpi())) * printScale, null);

                            }
                            txtBm.recycle();
                        }
                    }
                }
                if(!isVip()) {
                    if (p.getWatermarks()!=null && !p.getWatermarks().isEmpty()) {
                        for(Page.Watermark watermark : p.getWatermarks()){
                            //draw water mark
                            Bitmap wm = Utils.getBitmapFromAsset(mContext, "magics/" + magicPath + "/pages/" + page + "/" + watermark.getSrc());
                            if (wm == null) {
                                wm = BitmapFactory.decodeResource(mContext.getResources(), R.drawable.watermask);
                            }
                            if(watermark.getScale()!=1){
                                wm = Utils.scaleBitmap(wm,watermark.getScale());
                            }
                            if(watermark.getAngle()!=0){
                                wm = Utils.rotateBitmap(wm,watermark.getAngle());
                            }
                            if(p.getOffsetY()>0) {
                                canvas.drawBitmap(wm, (p.getOffsetX() / 96 + (watermark.getX() * ph.getGrid() / 96)) * printScale * ph.getDpi(),
                                        ((templateHeight - p.getOffsetY() / 96 * ph.getDpi()) + ((watermark.getY() * ph.getGrid() / 96) * ph.getDpi())) * printScale, null);
                            }else  if(p.getOffsetX()>0){
                                canvas.drawBitmap(wm, (p.getOffsetX() / 96 + (watermark.getX() * ph.getGrid() / 96)) * printScale * ph.getDpi(),
                                        (templateHeight -  (( watermark.getY() / 96) * ph.getGrid() * ph.getDpi())) * printScale, null);
                            }else{
                                canvas.drawBitmap(wm, (watermark.getX()/ 96) * ph.getGrid() * printScale * ph.getDpi(),
                                        (templateHeight -  (( watermark.getY() / 96) * ph.getGrid() * ph.getDpi())) * printScale, null);

                            }
                            wm.recycle();
                        }
                    }
                }

                canvas.drawBitmap(template, 0, 0, null);
                bms.add(new PagePreview(p, workBitmap));
            }
        }

        return bms;


    }


    private void buildFace(Canvas canvas, String name, Magic magic, Page.Face face,
                           int templateHeight, float printScale, float offsetX, float offsetY, float scale, float dpi, float grid) {
        try {
            // Find the slice and source - following Flutter PageBuilderService._buildFace logic
            Magic.Slice slice = null;
            Magic.Source source = null;
            
            if (magic != null) {
                for (Magic.Source src : magic.getSources()) {
                    if (src.getId() == face.getSource()) {
                        source = src;
                        for (Magic.Slice sl : src.getSlices()) {
                            if (sl.getId() == face.getSlice()) {
                                slice = sl;
                                break;
                            }
                        }
                        break;
                    }
                }
            }

            if (slice == null || source == null) {
                Log.w(TAG, "Slice or source not found: source=" + face.getSource() + ", slice=" + face.getSlice());
                return;
            }

            // Load slice bitmap
            Bitmap bm = loadSlice(name, source.getId(), slice.getId());
            if (bm == null) {
                Log.w(TAG, "Failed to load slice image: source=" + source.getId() + ", slice=" + slice.getId());
                return;
            }

            // Apply face transforms - following Flutter PageBuilderService._buildFace logic
            if (face.getTransforms() != null && !face.getTransforms().isEmpty()) {
                for (Magic.Transform transform : face.getTransforms()) {
                    Log.d(TAG, "Applying face transform: " + transform.getType());
                    if ("perspective".equals(transform.getType())) {
                        bm = applyPerspectiveTransform(bm, transform.getParams());
                    } else if ("rotate".equals(transform.getType())) {
                        // Java: rotateTransform.transform(bm) then Utils.trim()
                        Magic.RotateTransform rotateTransform = new Magic.RotateTransform(slice, transform.getParams());
                        bm = Utils.trim(rotateTransform.transform(bm));
                    } else if ("scale".equals(transform.getType())) {
                        // Java: scaleTransform.transform(bm) then Utils.trim()
                        Magic.ScaleTransform scaleTransform = new Magic.ScaleTransform(slice, transform.getParams());
                        bm = Utils.trim(scaleTransform.transform(bm));
                    }
                    if (bm == null) break;
                }
            }

            if (bm == null) return;

            // Apply face rotation - following Flutter PageBuilderService._buildFace logic
            if (face.getAngle() != 0) {
                bm = Utils.rotateBitmap(bm, face.getAngle());
                if (bm == null) return;
            }

            // Apply scaling - following Flutter PageBuilderService._buildFace logic
            // Flutter: if (scale != 1) { scaleBitmapByFactor(sliceImage, scale * face.scale * printScale) } else { scaleBitmapByFactor(sliceImage, face.scale * printScale) }
            // Java adaptation: if (scale != 1) { scaleBitmap(bm, scale * printScale) } else { scaleBitmap(bm, printScale) }
            // Note: Java doesn't have face.scale yet, but keeping structure for future compatibility
            if (scale != 1) {
                bm = Utils.scaleBitmap(bm, scale * printScale);
            } else {
                bm = Utils.scaleBitmap(bm, printScale);
            }
            if (bm == null) return;

            // Calculate position - following Flutter PageBuilderService._buildFace logic exactly
            float x, y;
            if (offsetY > 0) {
                x = (offsetX / 96 + (face.getX() * grid / 96)) * printScale * dpi;
                y = ((templateHeight - offsetY / 96 * dpi) + ((face.getY() * grid / 96) * dpi)) * printScale;
            } else if (offsetX > 0) {
                x = (offsetX / 96 + (face.getX() * grid / 96)) * printScale * dpi;
                y = (templateHeight - ((face.getY() / 96) * grid * dpi)) * printScale;
            } else {
                x = (face.getX() / 96) * grid * printScale * dpi;
                y = (templateHeight - ((face.getY() / 96) * grid * dpi)) * printScale;
            }

            // Draw the slice
            canvas.drawBitmap(bm, x, y, null);
            
        } catch (Exception e) {
            Log.e(TAG, "Error building face: ", e);
        } finally {
            // Clean up bitmap to prevent memory leaks - always clean up in finally block
            // Note: We don't clean up here since the bitmap might be used elsewhere
            // Let GC handle it or implement proper bitmap pooling
        }
    }
}
