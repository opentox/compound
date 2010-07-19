import java.util.List;
import java.util.Arrays;
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
import org.openscience.cdk.templates.*;
import org.openscience.cdk.smiles.*;
import org.openscience.cdk.smiles.smarts.*;
import org.openscience.cdk.graph.*;
import org.openscience.cdk.geometry.*;

public class Display{

	int size;
	Rectangle drawArea;
	IMolecule molecule = new Molecule();
	IMoleculeSet moleculeSet;
	IMolecule[] coordinated_mols;
	StructureDiagramGenerator sdg = new StructureDiagramGenerator();
	SmilesParser sp = new SmilesParser(DefaultChemObjectBuilder.getInstance());
	AtomContainer matches = new AtomContainer();
	Vector<Integer> idlist = new Vector<Integer>();
	List generators = new ArrayList();
	Renderer renderer;
	BufferedImage image;
	Graphics2D g2;

	ByteArrayOutputStream out = new ByteArrayOutputStream();

	public Display (String smiles, int s) {

		size = s; 
		// generators make the image elements
		generators.add(new BasicSceneGenerator());
		generators.add(new BasicBondGenerator());
		generators.add(new RingGenerator());
		generators.add(new BasicAtomGenerator());
		renderer = new Renderer(generators, new AWTFontManager());
		try { molecule = sp.parseSmiles(smiles); }
		catch (Exception ex) { ex.printStackTrace(); }
		moleculeSet = ConnectivityChecker.partitionIntoMolecules(molecule);
		coordinated_mols = new IMolecule[moleculeSet.getMoleculeCount()];
		drawArea = new Rectangle(size, size);
		image = new BufferedImage(size, size , BufferedImage.TYPE_INT_RGB);
		g2 = (Graphics2D)image.getGraphics();
		g2.setColor(Color.yellow);
		g2.fillRect(0, 0, size, size);
	}

	public byte[] image() {
		try {
			Rectangle2D last = new Rectangle(0,0);
			for (int i = 0; i < moleculeSet.getMoleculeCount(); i++) {
				IAtomContainer mol = moleculeSet.getMolecule(i);
				sdg.setMolecule((IMolecule) mol);
				sdg.generateCoordinates();
				mol = sdg.getMolecule();
				GeometryTools.translateAllPositive(mol);
				
				// get size of previous mol and shift
				last = GeometryTools.shiftContainer(mol, GeometryTools.getRectangle2D(mol), last,2);
				coordinated_mols[i] = (IMolecule) mol;
			}
			moleculeSet.setMolecules(coordinated_mols);
			renderer.paintMoleculeSet(moleculeSet, new AWTDrawVisitor(g2), drawArea, true);
			//matchSmarts("NN",Color.green);
			ImageIO.write(image, "png", out);
		} catch (Exception ex) {
				ex.printStackTrace();
		}
		return out.toByteArray();
	}

//	public Image match(String smiles, String smarts) {
//	}
	private void matchSmarts(String smarts, Color color) {
		try {
			// map smarts
				SMARTSQueryTool querytool = new SMARTSQueryTool(smarts);
				boolean status = querytool.matches(molecule);
				if (status) {
					List<List<java.lang.Integer>>	mappings = querytool.getMatchingAtoms();
					int nmatch = querytool.countMatches();
					for (int i = 0; i < nmatch; i++) {
						List atomIndices = (List) mappings.get(i);
						for (int n = 0; n < atomIndices.size(); n++) {
							Integer atomID = (Integer) atomIndices.get(n);
							idlist.add(atomID);
						}
					}
				}

				// get a unique list of bond ID's and add them to an AtomContainer
				HashSet<Integer> hs = new HashSet<Integer>(idlist);
				for (Integer h : hs) {
					IAtom a = molecule.getAtom(h);
					List bond_list = molecule.getConnectedBondsList(a);
					for (int i = 0; i < bond_list.size(); i++) {
						IBond b = (IBond) bond_list.get(i);
						Integer connectedNr = molecule.getAtomNumber(b.getConnectedAtom(a));
						//if (hs.contains(connectedNr)) renderer.getRenderer2DModel().getColorHash().put(b, color);
					}
				}

		} catch (Exception exc) {
				exc.printStackTrace();
		}

	}

}

