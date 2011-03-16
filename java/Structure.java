import java.util.List;
import java.util.HashMap;
import java.util.Map;
import java.util.*;
import java.lang.Math;
import java.io.*;

import java.awt.*;
import java.awt.image.*;
import java.awt.geom.*;

import javax.imageio.*;

import org.openscience.cdk.*;
import org.openscience.cdk.interfaces.*;
import org.openscience.cdk.layout.*;
import org.openscience.cdk.renderer.*;
import org.openscience.cdk.renderer.font.*;
import org.openscience.cdk.renderer.generators.*;
import org.openscience.cdk.renderer.visitor.*;
import org.openscience.cdk.renderer.selection.*;
import org.openscience.cdk.templates.*;
import org.openscience.cdk.smiles.*;
import org.openscience.cdk.smiles.smarts.*;
import org.openscience.cdk.graph.*;
import org.openscience.cdk.geometry.*;

public class Structure{

  int size;
  List generators = new ArrayList();

  IMolecule molecule = new Molecule();
  IMoleculeSet moleculeSet;
  IMolecule[] coordinated_mols;

  StructureDiagramGenerator sdg = new StructureDiagramGenerator();
  SmilesParser sp = new SmilesParser(DefaultChemObjectBuilder.getInstance());

  List<IChemObject> matchingBonds = new ArrayList<IChemObject>();
  List<IChemObject> activatingBonds = new ArrayList<IChemObject>();
  List<IChemObject> deactivatingBonds = new ArrayList<IChemObject>();

  Map<IChemObject,Color> coloredMatches = new HashMap<IChemObject,Color>();
  Renderer renderer;

  BufferedImage image;
  Rectangle drawArea;
  Graphics2D g2;

  ByteArrayOutputStream out = new ByteArrayOutputStream();

  public Structure (String smiles, int imageSize) {

    size = imageSize; 

    // generators make the image elements
    generators.add(new BasicSceneGenerator());
    generators.add(new RingGenerator());
    generators.add(new BasicBondGenerator());
    generators.add(new BasicAtomGenerator());

    renderer = new Renderer(generators, new AWTFontManager());

    try { molecule = sp.parseSmiles(smiles); }
    catch (Exception ex) { ex.printStackTrace(); }

    moleculeSet = ConnectivityChecker.partitionIntoMolecules(molecule);
    coordinated_mols = new IMolecule[moleculeSet.getMoleculeCount()];

    drawArea = new Rectangle(size, size);
    image = new BufferedImage(size, size , BufferedImage.TYPE_INT_RGB);

    g2 = (Graphics2D)image.getGraphics();
    g2.setColor(Color.WHITE);
    g2.fillRect(0, 0, size, size);

    layout();

  }

  public byte[] show() {
    try {
      // set colors
      for (int i = 0; i < matchingBonds.size(); i++) {
        float red = 0;
        float green = 0;
        IChemObject bond = (IChemObject) matchingBonds.get(i);
        if (activatingBonds.contains(bond)) { red = 1; };
        if (deactivatingBonds.contains(bond)) { green = 1; };
        coloredMatches.put((IChemObject) bond , new Color(red,green,0));
      }
      renderer.getRenderer2DModel().set( RendererModel.ColorHash.class, coloredMatches );
      // render and write
      renderer.paintMoleculeSet(moleculeSet, new AWTDrawVisitor(g2), drawArea, true);
      ImageIO.write(image, "png", out);
    }
    catch (Exception ex) { ex.printStackTrace(); }
    return out.toByteArray();
  }

  private void layout() {
    try {
      Rectangle2D last = new Rectangle(0,0);
      // reverse iteration to show small molecules at the right side
      for (int i = moleculeSet.getMoleculeCount()-1; i >= 0 ; i--) {
        IAtomContainer mol = moleculeSet.getMolecule(i);
        sdg.setMolecule((IMolecule) mol);
        sdg.generateCoordinates();
        mol = sdg.getMolecule();
        // get size of previous mol and shift to the right
        // gives nasty results for single atom molecules, but works otherwise
        // last = GeometryTools.shiftContainer(mol, GeometryTools.getRectangle2D(mol), last, 0);
        // fix suggested by http://sourceforge.net/mailarchive/forum.php?thread_name=AANLkTikJQSjFkNCmO2gb0jw5PQxZRoFSTbruOa2DMCmZ%40mail.gmail.com&forum_name=cdk-jchempaint
        // shifts single atoms to the right, but does not adjust the layout of larger structures
        Rectangle2D bb = GeometryTools.getRectangle2D(mol);
        Rectangle2D minBB = new Rectangle2D.Double(bb.getX(), bb.getY(), Math.max(bb.getWidth(), 15), bb.getHeight());
        last = GeometryTools.shiftContainer(mol, minBB, last, 0);
        coordinated_mols[i] = (IMolecule) mol;
      }
      moleculeSet.setMolecules(coordinated_mols);
    }
    catch (Exception ex) { ex.printStackTrace(); }
  }

  public void match_activating(String[] smarts) {
    for (int i = 0; i < smarts.length; i++) {
      match(smarts[i],true);
    }
  }

  public void match_deactivating(String[] smarts) {
    for (int i = 0; i < smarts.length; i++) {
      match(smarts[i],false);
    }
  }

  public void match(String smarts) { match(smarts, true); }

  public void match(String smarts, Boolean active) {

    try {
      int count;
      SMARTSQueryTool querytool = new SMARTSQueryTool(smarts);
      // iterate over molecule set
      for (int i = 0; i < moleculeSet.getMoleculeCount(); i++) {
        IAtomContainer mol = moleculeSet.getMolecule(i);
        ChemModel fragment = new ChemModel();
        // match smarts
        boolean status = querytool.matches(mol);
        if (status) {
          List matches = querytool.getUniqueMatchingAtoms();
          // iterate over all matches
          for (int j = 0; j < matches.size(); j++) {
            List atomIndices = (List) matches.get(j);
            // itrate over all atoms
            for (int k = 0; k < atomIndices.size(); k++) {
              IAtom a1 = mol.getAtom( (Integer) atomIndices.get(k));
              // find bonds
              for (int l = k + 1; l < atomIndices.size(); l++) {
                IAtom a2 = mol.getAtom( (Integer) atomIndices.get(l));
                IChemObject bond = (IChemObject) mol.getBond(a1,a2);
                if (bond != null) {
                  // collect all/active/inactive bonds
                  if (!matchingBonds.contains(bond)) { matchingBonds.add(bond); }
                  if (active) {
                    if (!activatingBonds.contains(bond)) { activatingBonds.add(bond); }
                  } else {
                    if (!deactivatingBonds.contains(bond)) { deactivatingBonds.add(bond); }
                  }
                }
              }
            }
          }
        }
      }

    }
    catch (Exception exc) { exc.printStackTrace(); }
  }

}
