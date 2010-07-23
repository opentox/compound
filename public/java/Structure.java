import java.util.List;
import java.util.*;
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
  Renderer renderer;

  BufferedImage image;
  Rectangle drawArea;
  Graphics2D g2;

  LogicalSelection selection = new LogicalSelection(LogicalSelection.Type.ALL);
  MoleculeSet selectionMoleculeSet = new MoleculeSet();
  ChemModel selectionChemModel = new ChemModel();

  ByteArrayOutputStream out = new ByteArrayOutputStream();

  public Structure (String smiles, int imageSize) {

    size = imageSize; 

    // generators make the image elements
    generators.add(new BasicSceneGenerator());
    generators.add(new RingGenerator());
    generators.add(new BasicBondGenerator());
    generators.add(new BasicAtomGenerator());
    generators.add(new SelectBondGenerator());
    generators.add(new SelectAtomGenerator());

    renderer = new Renderer(generators, new AWTFontManager());
    renderer.getRenderer2DModel().set( SelectBondGenerator.SelectionBondColor.class,Color.RED);

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
      // create a fake ChemModel to make the LogicalSelection happy
      selectionChemModel.setMoleculeSet(selectionMoleculeSet);
      selection.select(selectionChemModel);
      renderer.getRenderer2DModel().setSelection(selection);
      renderer.paintMoleculeSet(moleculeSet, new AWTDrawVisitor(g2), drawArea, true);
      ImageIO.write(image, "png", out);
    }
    catch (Exception ex) { ex.printStackTrace(); }
    return out.toByteArray();
  }

  private void layout() {
    try {
      Rectangle2D last = new Rectangle(0,0);
      for (int i = 0; i < moleculeSet.getMoleculeCount(); i++) {
        IAtomContainer mol = moleculeSet.getMolecule(i);
        sdg.setMolecule((IMolecule) mol);
        sdg.generateCoordinates();
        mol = sdg.getMolecule();
        GeometryTools.translateAllPositive(mol);
        // get size of previous mol and shift to the right
        last = GeometryTools.shiftContainer(mol, GeometryTools.getRectangle2D(mol), last,2);
        coordinated_mols[i] = (IMolecule) mol;
      }
      moleculeSet.setMolecules(coordinated_mols);
    }
    catch (Exception ex) { ex.printStackTrace(); }
  }

  public void match_activating(String[] smarts) {
    for (int i = 0; i < smarts.length; i++) {
      match(smarts[i]);
    }
  }

  public void match_deactivating(String[] smarts) {
    renderer.getRenderer2DModel().set( SelectBondGenerator.SelectionBondColor.class,Color.GREEN);
    for (int i = 0; i < smarts.length; i++) {
      match(smarts[i]);
    }
  }

  public void match(String smarts) {

    try {
      SMARTSQueryTool querytool = new SMARTSQueryTool(smarts);
      // iterate over molecule set
      for (int i = 0; i < moleculeSet.getMoleculeCount(); i++) {
        IAtomContainer mol = moleculeSet.getMolecule(i);
        ChemModel fragment = new ChemModel();
        // match smarts
        boolean status = querytool.matches(mol);
        if (status) {
          List matches = querytool.getUniqueMatchingAtoms();
          //System.out.print("Matches: ");
          //System.out.println(matches);
          // iterate over all matches
          for (int j = 0; j < matches.size(); j++) {
            IAtomContainer selectionContainer = new AtomContainer();
            List atomIndices = (List) matches.get(j);
            // itrate over all atoms
            for (int k = 0; k < atomIndices.size(); k++) {
              IAtom a1 = mol.getAtom( (Integer) atomIndices.get(k));
              if (!selectionContainer.contains(a1)) {  selectionContainer.addAtom(a1); }
              // find bonds
              for (int l = k + 1; l < atomIndices.size(); l++) {
                IAtom a2 = mol.getAtom( (Integer) atomIndices.get(l));
                IBond bond = mol.getBond(a1,a2);
                if (bond != null) { selectionContainer.addBond(bond); }
              }
            }
            // create a fake MoleculeSet to make the LogicalSelection happy
            selectionMoleculeSet.addMolecule(new Molecule(selectionContainer));
          }
        }
      }

    }
    catch (Exception exc) { exc.printStackTrace(); }

  }

}
